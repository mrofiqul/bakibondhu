# Specification Review — BakiBondhu Platform Spec Set

**Reviewed:** 2026-09-07
**Documents reviewed (as a set):**

- `BakiBondhu_Android_Web_Application_Specification_v1.1.docx` (canonical app spec)
- `BakiBondhu_Android_Web_Application_Specification.docx` (v1.0 — superseded)
- `BakiBondhu_Database_Specification.docx` + `BakiBondhu_PostgreSQL_Schema.sql`
- `BakiBondhu_REST_API_Specification.docx` / `.md`

---

## 1. Verdict

A strong, professional specification set. The three technical documents are **internally
consistent and cross-referenced**: the DB spec and REST API both cite the app-spec section
numbers they implement, the `.sql` file matches the DB-spec doc verbatim, enum values line up
across all three, and pricing (Pro ৳249 / Business ৳1499) sits inside the app-spec ranges.
The core architecture is sound — append-only ledger with a directional `balance_sign`,
balances computed via view (never stored), UUID PKs for offline id-generation, `NUMERIC(14,2)`
money, and `timestamptz` storage.

`§42` of the app spec already records the right scope caution (validate first; ship
Android-only local-first; add the backend once retention is proven). This review therefore
focuses on a small number of **real technical gaps** worth closing before the DB/API are
treated as firm build contracts.

Severity: **H** = fix before building against it · **M** = fix soon · **L** = cosmetic.

---

## 2. Findings

### H1 · Aging did not subtract payments — it could not reconcile with the balance
Both the `customer_aging` view and `GET /receivables/aging` bucketed **gross credit amounts**
by `due_date` and never netted out payments, because payments were not tied to the credits
they settle. Once a customer made any partial payment, aging-bucket total ≠ balance. The API
example only *looked* correct because its numbers were chosen so the buckets happened to equal
the balance. There was also no payment-application (invoice allocation) model, so the
remaining balance could not be aged FIFO (oldest-first), which is the receivables standard.

**Status: fixed in schema (partial) + app work required.** See §3 — a `payment_allocations`
table was added and `customer_aging` now ages the *unpaid* portion of each credit. The
application must populate allocations (FIFO by `due_date`) at payment time; see O1.

### H2 · Tenant-isolation RLS had two defects
1. **Silently disabled for the table owner.** `ENABLE ROW LEVEL SECURITY` is not enforced for
   the role that owns the table (nor any `BYPASSRLS` role). If migrations and the app connect
   as the same owner role — the common default — the entire RLS defense layer was a no-op.
2. **`business_users` in the tenant loop broke multi-business login.** Resolving *which*
   businesses a user belongs to requires querying `business_users` by `user_id` **before** a
   business is selected, but the policy required `business_id = current_setting(...)`, which is
   unset then → zero rows → login/business-picker impossible.

**Status: fixed in schema.** See §3 — `FORCE ROW LEVEL SECURITY` + a dedicated non-owner
app-role note; `business_users` moved to a user-scoped `membership_visibility` policy.

### M3 · `promise_to_pay` was missing offline sync fields
It is an Android-created screen (`§8.9`) and `/sync/pull` returns `promises`, yet unlike
`collection_activities` it lacked `local_id` / `device_id` / `sync_status`.
**Status: fixed in schema** (fields + partial sync index added).

### M4 · Aging used the server date, not the business timezone
`CURRENT_DATE − due_date` on a UTC server miscounts "days overdue" by one for ~6 hours around
midnight Dhaka time. **Status: fixed in schema** — aging now computes "today" as
`(now() AT TIME ZONE business.timezone)::date`. Note that not-yet-due credits fall in no
bucket, so the aging total is *total overdue*, not total outstanding — label the API field
accordingly (see O3).

### L5 · Money serialized as JSON number
The API sends money as JSON numbers with a "treat as fixed-decimal" warning. Serializing money
as **strings** removes all floating-point ambiguity at the client. *Recommendation only.*

### L6 · `transaction_types` comment vs. seed codes
The column comment said `'adjustment'|'reversal'`; the seed inserts
`adjustment_debit`/`adjustment_credit`. **Status: comment corrected in schema.**

### L7 · DB idempotency constraint does not cover web-created transactions
`UNIQUE(business_id, device_id, local_id)` does not dedupe web rows (both NULL → NULLs are
distinct in a UNIQUE constraint). Web correctly relies on the `Idempotency-Key` store instead;
just state this explicitly in both docs. *Documentation only.*

### L8 · SMS `cost: 0.35`
Masked/transactional SMS in Bangladesh typically costs more than ৳0.35; validate before it
feeds reminder margin. *Same note as the earlier financial-model review.*

---

## 3. Fixes applied to `BakiBondhu_PostgreSQL_Schema.sql`

All changes validated: 41/41 DDL statements parse under the PostgreSQL dialect.

| # | Change |
|---|--------|
| 1 | **Added `payment_allocations`** (payment→credit application) with FK/unique/indexes and RLS. |
| 2 | **Rewrote `customer_aging`** to age the *unpaid* portion of each credit (`amount − Σ allocations`) and to compute overdue days in the **business timezone**. |
| 3 | **RLS hardened:** `FORCE ROW LEVEL SECURITY` on all tenant tables + a dedicated non-owner app-role note. |
| 4 | **`business_users` RLS** replaced with a user-scoped `membership_visibility` policy so multi-business login works. |
| 5 | **`promise_to_pay`** gained `local_id`, `device_id`, `sync_status` + a partial sync index. |
| 6 | **`transaction_types`** column comment corrected to the real codes. |
| 7 | Header revision note added (`rev. 2026-09-07`). |

> The `BakiBondhu_Database_Specification.docx` embeds the same schema text and is now **behind
> the `.sql`** — regenerate it from the updated `.sql` so the doc and the runnable file match.

---

## 4. Open recommendations (not auto-fixable)

- **O1 · FIFO payment allocation — SPECIFIED (2026-09-07).** The reference implementation
  `reallocate_customer(business_id, customer_id)` is now in the schema (DB spec §13c), with the
  full algorithm, trigger points, reversal behavior, overpayment, concurrency and a worked
  example in the Offline Sync Technical Design §5; the aging view was made reversal-consistent.
  **Remaining:** wire `SELECT reallocate_customer(...)` into the API transaction endpoints
  (payment / credit / reverse) within the same DB transaction as the insert.
- **O2 · Regenerate the DB-spec `.docx` and re-check the REST API examples** against the
  corrected aging semantics (an aging response should reconcile with the balance).
- **O3 · Rename the aging total** in `GET /receivables/aging` from `total_outstanding` to
  `total_overdue` (or add a separate not-yet-due figure), reflecting that aging covers overdue
  credit only.
- **O4 · Serialize money as strings** in the API (L5).
- **O5 · Concurrency on overpayment:** the "payment exceeds outstanding" check reads the
  balance at write time; guard against two concurrent payments (row lock or a post-write check).

---

## 5. Housekeeping

- Two app-spec versions live in the folder. **v1.1 is canonical** (the DB and API target it);
  move `BakiBondhu_Android_Web_Application_Specification.docx` (v1.0) to `archive/`.
- The earlier local-first MVP spec in [phase1-mvp/](phase1-mvp/README.md) and this full-platform spec describe
  **different scopes on purpose** (see app-spec `§42`). A one-line pointer from the docs README
  to `§42` will save a future reader the confusion.

---

*Prepared during specification review · 2026-09-07. Schema fixes are in
`BakiBondhu_PostgreSQL_Schema.sql`; this document records what changed and what remains.*
