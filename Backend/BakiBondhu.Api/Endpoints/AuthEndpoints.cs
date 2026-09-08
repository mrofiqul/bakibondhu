using BakiBondhu.Api.Security;
using BakiBondhu.Infrastructure;
using Dapper;

namespace BakiBondhu.Api.Endpoints;

public record RegisterRequest(string name, string? phone, string? email, string password, string business_name, string? area);
public record LoginRequest(string identifier, string password);

/// <summary>Auth (REST API §2): register creates the owner + business; login
/// verifies the password and returns a JWT scoped to the user's business.</summary>
public static class AuthEndpoints
{
    public static void Map(RouteGroupBuilder v1)
    {
        var auth = v1.MapGroup("/auth");
        auth.MapPost("/register", Register);
        auth.MapPost("/login", Login);
    }

    private static async Task<IResult> Register(RegisterRequest req, AppDb db, JwtService jwt)
    {
        if (string.IsNullOrWhiteSpace(req.password) || string.IsNullOrWhiteSpace(req.business_name) ||
            (string.IsNullOrWhiteSpace(req.phone) && string.IsNullOrWhiteSpace(req.email)))
        {
            return Results.BadRequest(new { error = new { code = "validation_failed", message = "phone or email, password and business_name are required" } });
        }

        await using var conn = await db.OpenAsync();
        await using var tx = await conn.BeginTransactionAsync();

        var exists = await conn.ExecuteScalarAsync<long>(
            "SELECT COUNT(*) FROM users WHERE (@phone IS NOT NULL AND phone=@phone) OR (@email IS NOT NULL AND email=@email)",
            new { req.phone, req.email }, tx);
        if (exists > 0)
            return Results.Conflict(new { error = new { code = "conflict", message = "a user with that phone/email already exists" } });

        var userId = Guid.NewGuid();
        await conn.ExecuteAsync(
            "INSERT INTO users(id,name,phone,email,password_hash) VALUES(@id,@name,@phone,@email,@hash)",
            new { id = userId, req.name, req.phone, req.email, hash = PasswordHasher.Hash(req.password) }, tx);

        var businessId = Guid.NewGuid();
        await conn.ExecuteAsync(
            "INSERT INTO businesses(id,name,owner_user_id,area) VALUES(@id,@name,@owner,@area)",
            new { id = businessId, name = req.business_name, owner = userId, req.area }, tx);

        // Tenant context so the RLS WITH CHECK on business_users passes.
        await AppDb.SetTenantAsync(conn, tx, businessId, userId);
        var ownerRoleId = await conn.ExecuteScalarAsync<Guid>("SELECT id FROM roles WHERE code='owner'", transaction: tx);
        await conn.ExecuteAsync(
            "INSERT INTO business_users(business_id,user_id,role_id) VALUES(@b,@u,@r)",
            new { b = businessId, u = userId, r = ownerRoleId }, tx);

        await tx.CommitAsync();

        var (token, expiresIn) = jwt.Issue(userId, businessId, "owner");
        return Results.Json(new
        {
            user = new { id = userId, req.name, req.phone },
            business = new { id = businessId, name = req.business_name, timezone = "Asia/Dhaka", currency = "BDT" },
            role = "owner",
            tokens = new { access_token = token, access_expires_in = expiresIn },
        }, statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> Login(LoginRequest req, AppDb db, JwtService jwt)
    {
        await using var conn = await db.OpenAsync();

        var row = (IDictionary<string, object>?)await conn.QuerySingleOrDefaultAsync(
            "SELECT id, password_hash FROM users WHERE phone=@i OR email=@i", new { i = req.identifier });

        var unauthorized = Results.Json(new { error = new { code = "unauthenticated", message = "invalid credentials" } },
            statusCode: StatusCodes.Status401Unauthorized);
        if (row is null || row["password_hash"] is not string hash || !PasswordHasher.Verify(req.password, hash))
            return unauthorized;

        var userId = (Guid)row["id"];

        await using var tx = await conn.BeginTransactionAsync();
        await AppDb.SetTenantAsync(conn, tx, null, userId);
        var membership = (IDictionary<string, object>?)await conn.QuerySingleOrDefaultAsync(
            @"SELECT bu.business_id, r.code AS role
              FROM business_users bu JOIN roles r ON r.id = bu.role_id
              WHERE bu.user_id=@u AND bu.status='active' LIMIT 1",
            new { u = userId }, tx);
        await tx.CommitAsync();

        if (membership is null)
            return Results.Json(new { error = new { code = "forbidden", message = "no active business membership" } },
                statusCode: StatusCodes.Status403Forbidden);

        var businessId = (Guid)membership["business_id"];
        var role = (string)membership["role"];
        var (token, expiresIn) = jwt.Issue(userId, businessId, role);
        return Results.Ok(new { role, business_id = businessId, tokens = new { access_token = token, access_expires_in = expiresIn } });
    }
}
