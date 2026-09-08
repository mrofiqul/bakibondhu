using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace BakiBondhu.Api.Security;

/// <summary>Issues JWT access tokens carrying user, business and role claims
/// (REST API spec §2/§14). Refresh tokens are a follow-up.</summary>
public sealed class JwtService
{
    public const string BusinessClaim = "business_id";
    public const string RoleClaim = "role";

    private readonly SymmetricSecurityKey _key;
    private readonly string _issuer;
    private readonly int _minutes;

    public JwtService(string key, string issuer, int accessMinutes)
    {
        _key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        _issuer = issuer;
        _minutes = accessMinutes;
    }

    public SymmetricSecurityKey SigningKey => _key;
    public string Issuer => _issuer;

    public (string token, int expiresIn) Issue(Guid userId, Guid businessId, string role)
    {
        var creds = new SigningCredentials(_key, SecurityAlgorithms.HmacSha256);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new Claim(BusinessClaim, businessId.ToString()),
            new Claim(RoleClaim, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };
        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _issuer,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_minutes),
            signingCredentials: creds);
        return (new JwtSecurityTokenHandler().WriteToken(token), _minutes * 60);
    }
}
