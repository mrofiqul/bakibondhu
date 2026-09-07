# BakiBondhu — Development & Coding Standards

**Version 1.0** · Companion to the Application Specification (v1.1)
Defines repository structure, conventions, and quality gates for the backend, Android, and
web codebases. Implements app-spec §28 (project structure) and §26 (testing).

---

## 1. Purpose

One consistent way of working across three codebases so any contributor can navigate and
extend the system safely. Business rules live in the backend and are shared by both clients
(§29); these standards keep that boundary clean.

## 2. Repository layout

Mono-repo or three repos; either way the structure follows app-spec §28.

### 2.1 Backend — `BakiBondhu.Api` (ASP.NET Core, Clean Architecture)
```
BakiBondhu.Api            → controllers, DTOs, filters, auth, composition root
BakiBondhu.Application    → use-cases, validators, DTO mapping, interfaces
BakiBondhu.Domain         → entities, value objects, domain rules (balance, allocation)
BakiBondhu.Infrastructure → EF Core/Dapper, PostgreSQL, gateways, RLS session setup
BakiBondhu.Tests          → unit + integration tests
```
- **Domain has no framework dependencies.** Balance = Σ(amount × balance_sign), FIFO
  allocation, and aging rules live in Domain and are unit-tested in isolation.
- Every request sets the tenant context (`app.current_business_id`, `app.current_user_id`)
  and connects as the non-owner app role so RLS binds.

### 2.2 Android — Flutter (feature-first)
```
core/ data/ domain/
features/{auth,dashboard,customers,transactions,collections,reminders,settings}
sync/
```
- Local SQLite via drift/sqflite; repositories abstract local vs remote; the sync engine
  lives in `sync/` (see Offline Sync Technical Design).

### 2.3 Web — React + TypeScript
```
src/{components,pages,features,services,hooks,types,utils,auth}
```
- API access via a typed `services/` layer; server-driven tables; role gating in `auth/`.

## 3. Language & style conventions

| Stack | Formatter / linter | Naming |
|---|---|---|
| .NET | `dotnet format`, analyzers, nullable enabled | PascalCase types/methods, camelCase locals |
| Dart | `dart format`, `flutter analyze` | lowerCamelCase members, UpperCamelCase types |
| TypeScript | Prettier + ESLint, `strict: true` | camelCase, PascalCase components/types |

- No warnings in CI (treat analyzer warnings as errors on protected branches).
- Meaningful names over comments; comment the *why*, not the *what*. Match surrounding style.

## 4. API & data conventions

- REST per the API spec: versioned (`/api/v1`), JSON, JWT, standard status codes, the shared
  error envelope, server-side pagination/filter/sort.
- **Money** is `NUMERIC(14,2)` in the DB and serialized as a fixed-decimal string over the
  wire (no float). Timestamps are `timestamptz` (UTC); display in Asia/Dhaka.
- **UUID** ids everywhere (client-generatable for offline).
- **Idempotency-Key** on all financial POSTs; dedup on `(business_id, device_id, local_id)`.
- Financial writes are **append-only**; corrections are reversal/adjustment rows — never
  edits or deletes.

## 5. Localization (§33)

- No hard-coded user-facing strings; all text in Bangla resource files, English as optional
  secondary. Keys, not literals, in code.
- Currency/number formatting centralized (৳, lakh grouping, optional Bengali numerals).

## 6. Security standards (§22)

- No secrets in source; config via env/secrets manager. No customer PII in logs/analytics.
- Validate and sanitize all input at the API boundary; parameterized queries only.
- Enforce RBAC in the backend regardless of UI gating; deny by default.

## 7. Git & review workflow

- Trunk-based with short-lived branches; PRs required; at least one review.
- Conventional commit messages; small, focused PRs; CI must be green to merge.
- No direct pushes to protected branches; migrations reviewed with extra care.

## 8. Testing expectations (§26)

- Domain/business logic: high unit-test coverage (balances, allocation, aging, validators).
- Every API endpoint has an integration test (happy path + auth/RBAC + validation + tenant
  isolation). New behavior ships with tests. See the QA/Test-Case Specification.

## 9. Definition of done (per change)

- [ ] Meets its spec section; user-facing strings localized.
- [ ] Tests added/updated and green; analyzers clean.
- [ ] Tenant isolation respected (no query returns cross-business data).
- [ ] Financial invariants preserved (append-only; balance reconciles).
- [ ] Docs/spec updated if behavior or schema changed.

## 10. Dependency & versioning policy

- Pin versions; review and patch dependencies regularly (CI dependency audit).
- Semantic versioning for the API (`/api/v2` for breaking changes; `v1` stays stable) and
  for the Android app (with the server-enforced minimum version, §41).

## 11. Reference: the transactional write pattern (financial endpoints)

Every financial write follows the **same shape**, in **one database transaction**: set the
tenant context RLS reads → idempotency check → business-rule guard → append-only insert →
**`reallocate_customer` (FIFO allocation)** → audit → commit. This is the single place the
allocation call lives (DB spec §13c; Offline Sync §5). Never allocate outside the write's
transaction — aging must reconcile atomically with the insert.

```csharp
// POST /api/v1/transactions — record a credit or payment, then re-run FIFO allocation.
public async Task<TransactionResult> CreateAsync(CreateTransactionCommand cmd, CancellationToken ct)
{
    await using var conn = await _dataSource.OpenConnectionAsync(ct);
    await using var tx   = await conn.BeginTransactionAsync(ct);

    // 1) Tenant + user context that row-level security filters on (DB spec §14).
    //    The app connects as a NON-OWNER role, so these GUCs are what RLS enforces.
    await SetTenantContextAsync(conn, tx, _ctx.BusinessId, _ctx.UserId, ct);

    // 2) Idempotency: same Idempotency-Key / (business, device, local_id) returns the
    //    existing row — never a duplicate (API §14, DB unique constraint).
    if (await _txns.FindByIdempotencyAsync(conn, tx, cmd.BusinessId, cmd.DeviceId, cmd.LocalId, ct)
            is { } existing)
        return TransactionResult.Replayed(existing);

    // 3) Business-rule guard: block overpayment unless the business enabled it (§15).
    if (cmd.Type == TxnType.Payment && !_business.AllowOverpayment)
        await EnsureNotExceedingBalanceAsync(conn, tx, cmd.CustomerId, cmd.Amount, ct); // -> 409

    // 4) Append-only insert. amount > 0; direction comes from the type, never a sign (§15).
    var txn = await _txns.InsertAsync(conn, tx, cmd.ToEntity(_ctx.UserId), ct);

    // 5) *** FIFO allocation, in THIS transaction *** — idempotent + advisory-locked per
    //     customer inside the function, so aging reconciles atomically with the write.
    await conn.ExecuteAsync(new CommandDefinition(
        "SELECT reallocate_customer(@BusinessId, @CustomerId);",
        new { cmd.BusinessId, cmd.CustomerId }, tx, cancellationToken: ct));

    // 6) Audit (§15/§22) then commit.
    await _audit.RecordAsync(conn, tx, "create", "transaction", txn.Id, before: null, after: txn, ct);
    await tx.CommitAsync(ct);
    return TransactionResult.Created(txn);
}

// POST /api/v1/transactions/{id}/reverse — post the opposite-direction adjustment, then
// reallocate. Because the function ignores reversed txns, a plain reallocate does the rest.
public async Task<TransactionResult> ReverseAsync(Guid originalId, ReverseCommand cmd, CancellationToken ct)
{
    await using var conn = await _dataSource.OpenConnectionAsync(ct);
    await using var tx   = await conn.BeginTransactionAsync(ct);
    await SetTenantContextAsync(conn, tx, _ctx.BusinessId, _ctx.UserId, ct);

    var original = await _txns.GetAsync(conn, tx, originalId, ct) ?? throw new NotFoundException();
    var reversal = await _txns.InsertAsync(conn, tx, original.ToReversal(cmd.Reason, _ctx.UserId), ct);

    await conn.ExecuteAsync(new CommandDefinition(
        "SELECT reallocate_customer(@BusinessId, @CustomerId);",
        new { original.BusinessId, original.CustomerId }, tx, cancellationToken: ct));

    await _audit.RecordAsync(conn, tx, "reverse", "transaction", original.Id, before: original, after: reversal, ct);
    await tx.CommitAsync(ct);
    return TransactionResult.Created(reversal);
}

// Sets the PostgreSQL session GUCs RLS reads (DB spec §14). `is_local = true` scopes them
// to this transaction. Do this on EVERY request before touching tenant tables.
private static Task SetTenantContextAsync(DbConnection conn, DbTransaction tx,
                                          Guid businessId, Guid userId, CancellationToken ct)
    => conn.ExecuteAsync(new CommandDefinition(
        "SELECT set_config('app.current_business_id', @b, true), " +
        "       set_config('app.current_user_id',     @u, true);",
        new { b = businessId.ToString(), u = userId.ToString() }, tx, cancellationToken: ct));
```

**Sync batch (`POST /sync/push`).** Process the batch in one transaction, insert all items,
then call `reallocate_customer` **once per distinct affected customer** (not once per row):

```csharp
foreach (var customerId in affectedCustomerIds.Distinct())
    await conn.ExecuteAsync(new CommandDefinition(
        "SELECT reallocate_customer(@BusinessId, @CustomerId);",
        new { businessId, CustomerId = customerId }, tx, cancellationToken: ct));
```

**Rules this pattern encodes:**
- Allocation is **always** in the same transaction as the insert — never a fire-and-forget job.
- The three trigger points are **payment, credit, and reverse** (Offline Sync §5.3); a credit
  triggers it too, so a prior advance/overpayment is absorbed onto the new credit.
- If EF Core (not Dapper) is the data layer, the equivalent is
  `dbContext.Database.ExecuteSqlInterpolatedAsync($"SELECT reallocate_customer({businessId}, {customerId})")`
  on the same `DbContext` transaction.
