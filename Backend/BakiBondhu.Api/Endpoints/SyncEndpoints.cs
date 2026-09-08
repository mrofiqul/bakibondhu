using System.Security.Claims;
using System.Text.Json;
using BakiBondhu.Api.Security;
using BakiBondhu.Infrastructure;
using Dapper;

namespace BakiBondhu.Api.Endpoints;

public record PushChange(string entity, string local_id, string op, Dictionary<string, object?>? data);
public record PushRequest(string device_id, List<PushChange> changes);

/// <summary>
/// Offline sync (REST API §12), DB-backed, JWT-authenticated, tenant-scoped by
/// RLS. Push is idempotent on (business_id, device_id, local_id) and resolves a
/// transaction's customer_local_id to the server customer id; every transaction
/// insert re-runs reallocate_customer in the same transaction (Coding Std §11).
/// </summary>
public static class SyncEndpoints
{
    public static void Map(RouteGroupBuilder v1)
    {
        var sync = v1.MapGroup("/sync").RequireAuthorization();
        sync.MapPost("/push", Push);
        sync.MapGet("/pull", Pull);
    }

    private static (Guid businessId, Guid userId) Tenant(HttpContext http)
    {
        var sub = http.User.FindFirst("sub")?.Value ?? http.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var biz = http.User.FindFirst(JwtService.BusinessClaim)?.Value;
        return (Guid.Parse(biz!), Guid.Parse(sub!));
    }

    private static async Task<IResult> Push(HttpContext http, PushRequest req, AppDb db)
    {
        var (businessId, userId) = Tenant(http);
        var deviceId = Guid.Parse(req.device_id);

        await using var conn = await db.OpenAsync();
        await using var tx = await conn.BeginTransactionAsync();
        await AppDb.SetTenantAsync(conn, tx, businessId, userId);

        var results = new List<object>();
        var localCustomerToServer = new Dictionary<string, Guid>();

        foreach (var change in req.changes)
        {
            if (change.entity == "customer")
            {
                var serverId = await UpsertCustomer(conn, tx, businessId, userId, deviceId, change);
                localCustomerToServer[change.local_id] = serverId;
                results.Add(Result("customer", change.local_id, serverId));
            }
            else
            {
                var serverId = await UpsertTransaction(conn, tx, businessId, userId, deviceId, change, localCustomerToServer);
                results.Add(Result("transaction", change.local_id, serverId));
            }
        }

        await tx.CommitAsync();
        return Results.Ok(new { results, server_time = DateTimeOffset.UtcNow.ToString("o") });
    }

    private static object Result(string entity, string localId, Guid serverId) =>
        new { entity, local_id = localId, server_id = serverId.ToString(), sync_status = "SYNCED", reason = (string?)null };

    private static async Task<Guid> UpsertCustomer(
        Npgsql.NpgsqlConnection conn, Npgsql.NpgsqlTransaction tx,
        Guid businessId, Guid userId, Guid deviceId, PushChange change)
    {
        var existing = await conn.ExecuteScalarAsync<Guid?>(
            "SELECT id FROM customers WHERE business_id=@b AND device_id=@d AND local_id=@l",
            new { b = businessId, d = deviceId, l = Guid.Parse(change.local_id) }, tx);
        if (existing is Guid found) return found;

        var id = Guid.NewGuid();
        await conn.ExecuteAsync(
            @"INSERT INTO customers(id,business_id,name,phone,local_id,device_id,sync_status,created_by)
              VALUES(@id,@b,@name,@phone,@l,@d,'SYNCED',@u)",
            new
            {
                id, b = businessId, name = Str(change.data, "name"), phone = Str(change.data, "phone"),
                l = Guid.Parse(change.local_id), d = deviceId, u = userId,
            }, tx);
        return id;
    }

    private static async Task<Guid> UpsertTransaction(
        Npgsql.NpgsqlConnection conn, Npgsql.NpgsqlTransaction tx,
        Guid businessId, Guid userId, Guid deviceId, PushChange change,
        Dictionary<string, Guid> localCustomerToServer)
    {
        var existing = await conn.ExecuteScalarAsync<Guid?>(
            "SELECT id FROM transactions WHERE business_id=@b AND device_id=@d AND local_id=@l",
            new { b = businessId, d = deviceId, l = Guid.Parse(change.local_id) }, tx);
        if (existing is Guid found) return found;

        var localCustomer = Str(change.data, "customer_local_id")!;
        if (!localCustomerToServer.TryGetValue(localCustomer, out var customerId))
        {
            customerId = await conn.ExecuteScalarAsync<Guid>(
                "SELECT id FROM customers WHERE business_id=@b AND local_id=@l",
                new { b = businessId, l = Guid.Parse(localCustomer) }, tx);
        }

        var id = Guid.NewGuid();
        var amount = (Long(change.data, "amount_paisa") ?? 0) / 100m;
        await conn.ExecuteAsync(
            @"INSERT INTO transactions(id,business_id,customer_id,transaction_type_code,amount,due_date,note,local_id,device_id,created_by,sync_status)
              VALUES(@id,@b,@c,@type,@amt,@due::date,@note,@l,@d,@u,'SYNCED')",
            new
            {
                id, b = businessId, c = customerId, type = Str(change.data, "type"), amt = amount,
                due = Date(Str(change.data, "due_date")), note = Str(change.data, "note"),
                l = Guid.Parse(change.local_id), d = deviceId, u = userId,
            }, tx);

        // FIFO allocation so aging reconciles (DB spec §13c).
        await conn.ExecuteAsync("SELECT reallocate_customer(@b,@c)", new { b = businessId, c = customerId }, tx);
        return id;
    }

    private static async Task<IResult> Pull(HttpContext http, AppDb db, string? since)
    {
        var (businessId, userId) = Tenant(http);
        var sinceTs = DateTimeOffset.TryParse(since, out var s) ? s.UtcDateTime : DateTime.MinValue.ToUniversalTime();

        await using var conn = await db.OpenAsync();
        await using var tx = await conn.BeginTransactionAsync();
        await AppDb.SetTenantAsync(conn, tx, businessId, userId);

        var customers = (await conn.QueryAsync(
            "SELECT id,name,phone,updated_at FROM customers WHERE updated_at > @s ORDER BY updated_at",
            new { s = sinceTs }, tx)).Select(r =>
        {
            var d = (IDictionary<string, object>)r;
            return new Dictionary<string, object?>
            {
                ["id"] = ((Guid)d["id"]).ToString(),
                ["name"] = d["name"],
                ["phone"] = d["phone"],
                ["updated_at"] = ((DateTime)d["updated_at"]).ToString("o"),
            };
        }).ToList();

        var transactions = (await conn.QueryAsync(
            @"SELECT id,customer_id,transaction_type_code AS type,amount,due_date,note,updated_at
              FROM transactions WHERE updated_at > @s ORDER BY updated_at",
            new { s = sinceTs }, tx)).Select(r =>
        {
            var d = (IDictionary<string, object>)r;
            return new Dictionary<string, object?>
            {
                ["id"] = ((Guid)d["id"]).ToString(),
                ["customer_id"] = ((Guid)d["customer_id"]).ToString(),
                ["type"] = d["type"],
                ["amount_paisa"] = (long)Math.Round((decimal)d["amount"] * 100m),
                ["due_date"] = d["due_date"] switch
                {
                    DateOnly od => od.ToString("yyyy-MM-dd"),
                    DateTime dt => dt.ToString("yyyy-MM-dd"),
                    _ => null,
                },
                ["note"] = d.TryGetValue("note", out var n) ? n : null,
                ["updated_at"] = ((DateTime)d["updated_at"]).ToString("o"),
            };
        }).ToList();

        await tx.CommitAsync();
        return Results.Ok(new { customers, transactions, server_time = DateTimeOffset.UtcNow.ToString("o"), has_more = false });
    }

    // ---- JSON value helpers (System.Text.Json parses data values as JsonElement) ----
    private static string? Str(Dictionary<string, object?>? data, string key)
    {
        if (data is null || !data.TryGetValue(key, out var v) || v is null) return null;
        if (v is JsonElement je) return je.ValueKind == JsonValueKind.Null ? null : je.ToString();
        return v.ToString();
    }

    private static long? Long(Dictionary<string, object?>? data, string key)
    {
        if (data is null || !data.TryGetValue(key, out var v) || v is null) return null;
        if (v is JsonElement je)
            return je.ValueKind == JsonValueKind.Number ? je.GetInt64()
                 : long.TryParse(je.ToString(), out var n) ? n : null;
        return Convert.ToInt64(v);
    }

    private static string? Date(string? s) =>
        string.IsNullOrEmpty(s) ? null : DateTime.TryParse(s, out var dt) ? dt.ToString("yyyy-MM-dd") : null;
}
