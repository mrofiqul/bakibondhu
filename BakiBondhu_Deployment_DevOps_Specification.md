# BakiBondhu — Deployment & DevOps Specification

**Version 1.0** · Companion to the Application Specification (v1.1)
Covers infrastructure, environments, CI/CD, secrets, backups, observability, and release
process for the backend API, PostgreSQL, web app, and Android app.

---

## 1. Purpose & scope

Defines how BakiBondhu is built, deployed, operated, and recovered. Implements the
deployment items referenced in app-spec §4 (hosting), §22 (security), §26 (backup/restore),
and §41 (distribution, updates, observability).

## 2. Architecture in production

```
[ Android app ]  ──HTTPS──┐
                           ├──▶ [ API (ASP.NET Core) ] ──▶ [ PostgreSQL 13+ ]
[ Web app (React/CDN) ] ───┘             │                        │
                                          ├──▶ SMS/WhatsApp gateway (reminders, §34)
                                          └──▶ Object storage (report exports, §13)
```

- **Backend:** ASP.NET Core Web API, stateless, horizontally scalable behind a load balancer.
- **Database:** managed PostgreSQL (Azure Database for PostgreSQL / AWS RDS / equivalent),
  private network, automated backups, PITR enabled.
- **Web:** static React build served via CDN.
- **Hosting:** Cloud VPS / Azure / AWS or equivalent managed infra (§4).

## 3. Environments

| Env | Purpose | Data | Access |
|---|---|---|---|
| Local | Developer machines | Seed + synthetic | Developers |
| CI | Automated test on each push/PR | Ephemeral, seeded | Pipeline |
| Staging | Production-like validation, UAT | Anonymized/synthetic | Team |
| Production | Live | Real (PII-controlled) | Restricted, audited |

Config differs only by environment variables/secrets; the same build artifact is promoted
across environments (build once, deploy many).

## 4. Configuration & secrets (§22)

- **No secrets in source** (§22). Use a secrets manager (Azure Key Vault / AWS Secrets
  Manager / Doppler). Injected as env vars at deploy time.
- Distinct secrets per environment; least-privilege DB users. The **app connects as a
  dedicated non-owner role without BYPASSRLS** so row-level security binds (per DB spec §14).
- JWT signing keys rotated on a schedule; refresh-token revocation supported.

## 5. Database operations

- **Migrations:** versioned, forward-only with tested rollback; run as the schema-owner role
  in a release step, gated before app rollout. The canonical schema is
  `BakiBondhu_PostgreSQL_Schema.sql`.
- **Backups:** automated daily + WAL/PITR; retention policy documented; **quarterly restore
  drills** to a scratch instance verifying integrity and RLS (§26).
- **Indexes/scaling:** monitor slow queries; the hot indexes (business_id, customer_id,
  transaction_date, due_date) exist in the schema; add as data grows.
- **RLS in prod:** verify `FORCE ROW LEVEL SECURITY` is active and the app role is non-owner.

## 6. CI/CD pipeline

**On every push / PR:**
1. Restore, build (API, web, Android).
2. Lint + static analysis + `dotnet format`/eslint/`flutter analyze`.
3. Unit + integration tests (spin up a throwaway PostgreSQL; apply schema + migrations).
4. Security scan (dependency audit, SAST).
5. Build artifacts; publish on protected branches.

**On release (tag / protected branch):**
1. Deploy DB migrations to the target env (gated).
2. Deploy API (rolling / blue-green; health-checked).
3. Deploy web build to CDN (cache-busted).
4. Publish Android build (see §7).
5. Smoke tests against the environment; auto-rollback on health-check failure.

## 7. Android release & distribution (§41)

- **Google Play** distribution; signed release builds; staged rollout.
- **Versioning:** semantic version + build number; a **minimum-supported version** the API
  can enforce, with a **forced-update path** for breaking sync/schema changes (§41, Sync §7).
- Crash/error reporting (e.g. Crashlytics/Sentry) with **no customer PII** in reports (§36).
- Test the release build on a genuine low-end device before staged rollout.

## 8. Observability (§41)

- **Logs:** structured, centralized; correlation/`trace_id` (matches the API error envelope).
- **Metrics:** request rate/latency/error, DB connections, sync throughput, reminder
  delivery success/cost, queue depth.
- **Traces:** across API → DB → gateway.
- **Alerts:** error-rate spikes, DB CPU/connections, backup failure, reminder gateway
  failures, low SMS credit (§34), sync failure rate.
- **Audit:** `audit_logs` for who-changed-what; retained per policy (§36).

## 9. Security operations (§22)

- HTTPS/TLS everywhere; HSTS on web. Rate limiting on `/auth/*` and public endpoints.
- Restricted DB network access (private subnet); encryption at rest where supported.
- Dependency and image scanning in CI; timely patching.
- Incident response runbook; least-privilege IAM; access reviews.

## 10. Data lifecycle, privacy & compliance (§36)

- Merchant data export (CSV/Excel/PDF) and account/data-deletion honored operationally.
- Retention/archival policy for closed accounts and historical transactions.
- Align with applicable Bangladesh data-protection & telecom messaging rules; regulatory
  review gate before any payment/lending features (Phase 5).

## 11. Cost & scaling notes

- Start small (single small API instance + managed Postgres burstable + CDN) to match the
  pre-revenue posture; scale API horizontally and Postgres vertically/with read replicas as
  tenants grow. Reminder/SMS is a real per-message cost — meter and cap it (§34).

## 12. Release checklist

- [ ] Migrations applied & verified; rollback rehearsed.
- [ ] RLS FORCE active; app role non-owner.
- [ ] Secrets present per env; none in source.
- [ ] All QA acceptance cases green on staging (QA spec §12).
- [ ] Backups + restore drill current.
- [ ] Observability dashboards & alerts live.
- [ ] Android min-version gate set; forced-update path verified.
