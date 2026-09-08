namespace BakiBondhu.Api.Sync;

// Wire DTOs (snake_case matches the REST API spec §12 and the Flutter HttpSyncApi).
public record PushChange(string entity, string local_id, string op, Dictionary<string, object?>? data);
public record PushRequest(string device_id, List<PushChange> changes);
public record PushResultDto(string entity, string local_id, string? server_id, string sync_status, string? reason);
public record PushResponse(List<PushResultDto> results, string server_time);
public record PullResponse(
    List<Dictionary<string, object?>> customers,
    List<Dictionary<string, object?>> transactions,
    string server_time,
    bool has_more);

/// <summary>
/// In-memory DEV stand-in for the sync backend (no database, no auth, no tenant
/// isolation). Idempotent on (device_id, local_id); resolves a transaction's
/// customer_local_id to the customer's server id. Replace with the
/// PostgreSQL-backed implementation (schema + reallocate_customer) for prod.
/// </summary>
public class SyncService
{
    private readonly object _lock = new();
    private long _version;
    private readonly Dictionary<string, string> _idempotency = new();
    private readonly Dictionary<string, Stored> _customers = new();
    private readonly Dictionary<string, Stored> _transactions = new();

    private record Stored(string Id, Dictionary<string, object?> Data, long Version, DateTimeOffset UpdatedAt);

    public PushResponse Push(PushRequest req)
    {
        lock (_lock)
        {
            var results = new List<PushResultDto>();
            foreach (var change in req.changes)
            {
                var key = $"{req.device_id}|{change.local_id}";
                if (!_idempotency.TryGetValue(key, out var serverId))
                {
                    serverId = Guid.NewGuid().ToString();
                    _idempotency[key] = serverId;

                    var data = change.data is null
                        ? new Dictionary<string, object?>()
                        : new Dictionary<string, object?>(change.data);

                    // Resolve the client's customer_local_id -> server customer id
                    // (customers are pushed before their transactions in the batch).
                    if (change.entity == "transaction" &&
                        data.TryGetValue("customer_local_id", out var clid) && clid is not null &&
                        _idempotency.TryGetValue($"{req.device_id}|{clid}", out var custServerId))
                    {
                        data["customer_id"] = custServerId;
                    }

                    var record = new Stored(serverId, data, ++_version, DateTimeOffset.UtcNow);
                    (change.entity == "customer" ? _customers : _transactions)[serverId] = record;
                }
                results.Add(new PushResultDto(change.entity, change.local_id, serverId, "SYNCED", null));
            }
            return new PushResponse(results, _version.ToString());
        }
    }

    public PullResponse Pull(long since)
    {
        lock (_lock)
        {
            List<Dictionary<string, object?>> Rows(Dictionary<string, Stored> store) =>
                store.Values
                    .Where(r => r.Version > since)
                    .OrderBy(r => r.Version)
                    .Select(r => new Dictionary<string, object?>(r.Data)
                    {
                        ["id"] = r.Id,
                        ["updated_at"] = r.UpdatedAt.ToString("o"),
                    })
                    .ToList();

            return new PullResponse(Rows(_customers), Rows(_transactions), _version.ToString(), false);
        }
    }
}
