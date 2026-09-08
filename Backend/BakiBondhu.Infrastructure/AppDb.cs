using Npgsql;

namespace BakiBondhu.Infrastructure;

/// <summary>
/// Opens connections as the non-owner application role (so row-level security
/// binds) and sets the per-request tenant context that RLS reads. All tenant
/// queries run inside a transaction whose SET LOCAL app.current_* GUCs scope the
/// tenant to that transaction (DB spec §14, Coding Standards §11).
/// </summary>
public sealed class AppDb
{
    private readonly string _connectionString;
    public AppDb(string connectionString) => _connectionString = connectionString;

    public async Task<NpgsqlConnection> OpenAsync()
    {
        var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync();
        return conn;
    }

    /// Sets app.current_business_id / app.current_user_id LOCAL to [tx]. Only the
    /// provided ids are set (login sets user only, before a business is chosen).
    public static async Task SetTenantAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, Guid? businessId, Guid? userId)
    {
        if (businessId is Guid b)
            await SetAsync(conn, tx, "app.current_business_id", b.ToString());
        if (userId is Guid u)
            await SetAsync(conn, tx, "app.current_user_id", u.ToString());
    }

    private static async Task SetAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, string key, string value)
    {
        await using var cmd = new NpgsqlCommand("SELECT set_config(@k, @v, true)", conn, tx);
        cmd.Parameters.AddWithValue("k", key);
        cmd.Parameters.AddWithValue("v", value);
        await cmd.ExecuteNonQueryAsync();
    }
}
