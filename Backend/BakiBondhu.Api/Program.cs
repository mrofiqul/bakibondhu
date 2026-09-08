// BakiBondhu API — bootstrap.
//
// This is the runnable skeleton: it boots without a database and exposes a
// health check and a versioned ping. The real endpoints (auth, customers,
// transactions, sync) follow the REST API spec and use the transactional write
// pattern from Coding Standards §11 (every financial write ends with
// reallocate_customer in the same DB transaction). The schema lives in
// ../../documents/BakiBondhu_PostgreSQL_Schema.sql.

using BakiBondhu.Api.Sync;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// In-memory dev sync backend (see SyncService — replace with PostgreSQL-backed).
builder.Services.AddSingleton<SyncService>();

var app = builder.Build();

app.UseCors();

// Liveness/readiness probe (DevOps spec §8).
app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "bakibondhu-api",
    time = DateTimeOffset.UtcNow,
}));

// Versioned API root (REST API spec §1 — /api/v1). Real resources mount here.
var v1 = app.MapGroup("/api/v1");
v1.MapGet("/ping", () => Results.Ok(new { pong = true, version = "v1" }));

// Offline sync (REST API spec §12). Dev in-memory implementation.
var sync = v1.MapGroup("/sync");
sync.MapPost("/push", (PushRequest req, SyncService svc) => Results.Ok(svc.Push(req)));
sync.MapGet("/pull", (SyncService svc, string? since) =>
    Results.Ok(svc.Pull(long.TryParse(since, out var s) ? s : 0)));

app.Run();
