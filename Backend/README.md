# BakiBondhu — Backend API

The shared **ASP.NET Core Web API** and central **PostgreSQL** database. This is the
authoritative source for synchronized data and the single home of the business rules that
both the Android and Web apps use (app-spec §29). REST/JSON over HTTPS, JWT auth.

## Governing specifications

| Concern | Document |
|---|---|
| API contract (endpoints, request/response, errors) | `../documents/BakiBondhu_REST_API_Specification` |
| Data model, views, triggers, RLS, `reallocate_customer` | `../documents/BakiBondhu_Database_Specification` · `../documents/BakiBondhu_PostgreSQL_Schema.sql` |
| Offline sync (push/pull, conflicts, FIFO allocation) | `../documents/BakiBondhu_Offline_Sync_Technical_Design` |
| Product/functional requirements | `../documents/BakiBondhu_Android_Web_Application_Specification_v1.1` |
| Structure, style, the transactional write pattern | `../documents/BakiBondhu_Development_Coding_Standards` (§2.1, §11) |
| Build, deploy, secrets, backups, observability | `../documents/BakiBondhu_Deployment_DevOps_Specification` |
| Test strategy & fixtures (incl. allocation) | `../documents/BakiBondhu_QA_Test_Specification` |

## Folder structure (Coding Standards §2.1 — Clean Architecture)

```
BakiBondhu.Api/              controllers, DTOs, filters, auth, composition root
  Controllers/  Middleware/  Filters/  Auth/  Configuration/
BakiBondhu.Application/      use-cases, validators, mapping, interfaces (no framework deps)
  UseCases/  Validators/  Mapping/  Interfaces/  Dtos/
BakiBondhu.Domain/           entities + pure domain rules — NO framework dependencies
  Entities/  ValueObjects/  Rules/        (balance = Σ amount×balance_sign, allocation, aging)
  Enums/
BakiBondhu.Infrastructure/   EF Core/Dapper, PostgreSQL, gateways, RLS session, sync
  Persistence/  Repositories/  Gateways/  Sync/  Security/
BakiBondhu.Tests/            unit + integration
  Unit/  Integration/
```

## Dependency rule

`Api → Application → Domain` and `Infrastructure → Application/Domain`. **Domain depends on
nothing.** The balance, FIFO-allocation, and aging rules live in `Domain/Rules` and are
unit-tested in isolation (Coding Standards §2.1, §8).

## Getting started

1. Create the solution and five projects (matching the folders above), e.g.
   `dotnet new webapi -n BakiBondhu.Api`, `dotnet new classlib` for the other three, and
   `dotnet new xunit -n BakiBondhu.Tests`; wire the project references per the dependency rule.
2. Apply the schema: run `../documents/BakiBondhu_PostgreSQL_Schema.sql` (the canonical, runnable schema)
   against PostgreSQL 13+ as a migration step.
3. In `Infrastructure/Security`, set the RLS session context on every request
   (`app.current_business_id`, `app.current_user_id`) and connect as a **non-owner** DB role
   so row-level security binds (DB spec §14).
4. Implement the transaction endpoints using the pattern in **Coding Standards §11** — every
   financial write ends with `SELECT reallocate_customer(:business_id, :customer_id)` in the
   same transaction (see DB spec §13c, Offline Sync §5).

**Non-negotiables:** tenant isolation on every endpoint (no cross-business data); financial
writes are append-only with reversal/adjustment; idempotency on all financial POSTs; JWT +
RBAC; server-side pagination/filtering/sorting; money as `NUMERIC(14,2)` / fixed-decimal
strings; timestamps `timestamptz` (UTC), displayed Asia/Dhaka.
