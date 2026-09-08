namespace BakiBondhu.Api.Security;

/// <summary>Password hashing (BCrypt) — secure hashing per app-spec §22.</summary>
public static class PasswordHasher
{
    public static string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password);

    public static bool Verify(string password, string hash) =>
        BCrypt.Net.BCrypt.Verify(password, hash);
}
