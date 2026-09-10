// BakiBondhu API.
//
// Production-shaped: PostgreSQL (Npgsql/Dapper), JWT auth, and tenant isolation
// via row-level security (the app connects as a non-owner role and sets
// app.current_business_id / app.current_user_id per request). Endpoints follow
// the REST API spec; financial writes re-run reallocate_customer in the same
// transaction (Coding Standards §11).

using System.IdentityModel.Tokens.Jwt;
using System.Text;
using BakiBondhu.Api.Endpoints;
using BakiBondhu.Api.Security;
using BakiBondhu.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

// Keep original claim names ("sub", "business_id") instead of the SOAP-era URIs.
JwtSecurityTokenHandler.DefaultMapInboundClaims = false;

var builder = WebApplication.CreateBuilder(args);

// Cloud hosts (Render, Railway, Fly, …) inject the port to listen on via $PORT.
// Bind to it when present; local dev keeps its launchSettings/ASPNETCORE_URLS.
var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrWhiteSpace(port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var connectionString = builder.Configuration.GetConnectionString("App")
    ?? "Host=localhost;Port=5432;Database=bakibondhu;Username=bakibondhu_app;Password=app_pw";
var jwtKey = builder.Configuration["Jwt:Key"] ?? "dev-only-change-me-please-32-bytes-minimum-key!";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "bakibondhu";
var jwtMinutes = int.TryParse(builder.Configuration["Jwt:AccessMinutes"], out var m) ? m : 60;

builder.Services.AddSingleton(new AppDb(connectionString));
builder.Services.AddSingleton(new JwtService(jwtKey, jwtIssuer, jwtMinutes));

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = true,
            ValidAudience = jwtIssuer,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ValidateLifetime = true,
        };
    });
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Liveness probe.
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "bakibondhu-api", time = DateTimeOffset.UtcNow }));

var v1 = app.MapGroup("/api/v1");
v1.MapGet("/ping", () => Results.Ok(new { pong = true, version = "v1" }));

AuthEndpoints.Map(v1);   // anonymous
SyncEndpoints.Map(v1);   // requires a JWT

app.Run();
