# BakiBondhu — Specification Index

**The complete specification set for the BakiBondhu platform** (Android field app + Web
management app on one shared ASP.NET Core / PostgreSQL backend). This index is the entry
point: it lists every document, its status, and how they fit together.

_Last updated: 2026-09-07._

---

## 1. The two applications

- **Android app** (Flutter/Dart, offline-first, Bangla-first) — the primary field
  application for merchants and field staff.
- **Web app** (React/TypeScript) — management, reporting, monitoring, administration.
- Both use **one shared backend/API and central PostgreSQL database**; all business rules
  live in the backend (app-spec §29).

## 2. Document set

Every specification is provided in **Word (`.docx`)** and **Markdown (`.md`)**; the database
schema is also a runnable **`.sql`** file.

| # | Specification | Files | Status |
|---|---|---|---|
| 0 | **Specification Index** (this document) | `…_Specification_Index` | ✅ |
| 1 | **Application Specification** (product & technical, SRS) | `…_Android_Web_Application_Specification_v1.1` | ✅ canonical |
| 2 | **Database Specification** (+ runnable schema) | `…_Database_Specification` · `…_PostgreSQL_Schema.sql` | ✅ (rev. 2026-09-07) |
| 3 | **REST API Specification** | `…_REST_API_Specification` | ✅ |
| 4 | **Android UI/UX Specification** | `…_Android_UIUX_Specification` | ✅ new |
| 5 | **Web UI/UX Specification** | `…_Web_UIUX_Specification` | ✅ new |
| 6 | **Offline Synchronization Technical Design** | `…_Offline_Sync_Technical_Design` | ✅ new |
| 7 | **QA / Test-Case Specification** | `…_QA_Test_Specification` | ✅ new |
| 8 | **Deployment & DevOps Specification** | `…_Deployment_DevOps_Specification` | ✅ new |
| 9 | **Development & Coding Standards** | `…_Development_Coding_Standards` | ✅ new |
| — | **Specification Review** (findings + schema fixes) | `docs/spec-review.md` | ✅ |

Security is specified inline in the Application Specification (§22) and reinforced in the
Database (RLS), API (auth/RBAC), and DevOps specs, rather than as a separate document.

## 3. Reading order

1. **Application Specification** — the what and why (start here).
2. **Database Specification** — the data model and integrity rules.
3. **REST API Specification** — the contract between apps and backend.
4. **Android UI/UX** and **Web UI/UX** — screen-by-screen behavior.
5. **Offline Sync Technical Design** — how the field app stays correct offline.
6. **QA / Test-Case**, **Deployment & DevOps**, **Coding Standards** — build, verify, ship.

## 4. Cross-cutting invariants (true across all documents)

- **Multi-tenant:** every business row is isolated by `business_id`; no endpoint returns
  another business's data (§5). Enforced by API + PostgreSQL row-level security.
- **Append-only ledger:** financial transactions are never edited/deleted; corrections are
  reversal/adjustment rows with an audit trail (§15).
- **Balances are computed**, never stored: `balance = Σ(amount × balance_sign)` (§15). Aging
  ages the *unpaid* portion of each credit via FIFO payment allocation (review fix).
- **Offline-first Android:** the core loop works with no network; the server is authoritative;
  sync is idempotent on `(business_id, device_id, local_id)` (§16–17).
- **Bangla-first, ৳ only, Asia/Dhaka** display; UUID ids; money `NUMERIC(14,2)`; timestamps
  `timestamptz` (§33, §15).

## 5. Scope & phasing

The Application Specification is the long-term platform blueprint. Per app-spec **§42**, the
recommended build path is **validate first, then ship an Android-only, offline, local-first
MVP around the core loop**, and add the backend/web/roles once daily-use retention is proven.

**Phase-1 MVP reference (kept intentionally):** the earlier, narrower local-first MVP is
documented in [`docs/`](docs/README.md) and rendered as `BakiBondhu_MVP_Spec.pdf`. It is the
Phase-1 detail of §42 — a subset of this platform, not a competing spec.

**Strategy & validation assets (not specifications):** `BakiBondhu_Founders_Kit.pdf`,
`BakiBondhu_Interview_Script.pdf`, `BakiBondhu_Phase0_Merchant_Tracker.xlsx`, and
`BakiBondhu_Year1_Financials.xlsx` support Phase-0 validation and fundraising.

## 6. Open items carried from the review

Tracked in `docs/spec-review.md`:

- ✅ **FIFO payment allocation** — specified: `reallocate_customer()` in the schema (DB spec
  §13c), the full logic in Offline Sync Technical Design §5, and the aging view made
  reversal-consistent. Remaining work is to wire the call into the API's transaction endpoints.
- ✅ **DB-spec `.docx`** regenerated from the corrected `.sql`.
- Rename the aging response's `total_outstanding` → `total_overdue`; serialize money as
  strings; guard concurrent overpayment (the schema's advisory lock covers the DB side).
