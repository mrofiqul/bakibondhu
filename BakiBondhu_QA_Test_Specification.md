# BakiBondhu — QA / Test-Case Specification

**Version 1.0** · Companion to the Application Specification (v1.1)
Implements app-spec §26 (testing requirements) and validates §27 (MVP acceptance).

---

## 1. Purpose & scope

Defines the test strategy, environments, and concrete test cases across all layers: unit,
API integration, database, Android UI, web UI, sync, security, performance, and
backup/restore. Every case maps to an app-spec requirement so coverage is traceable.

## 2. Test strategy & pyramid

| Layer | Focus | Tooling (suggested) |
|---|---|---|
| Unit | Balance/aging/allocation logic; validators | xUnit (.NET), Dart test, Vitest |
| Integration (API) | Endpoint contracts, auth, RBAC, idempotency | .NET WebApplicationFactory, Postman/newman |
| Database | Constraints, triggers, views, RLS | pgTAP / SQL fixtures |
| Android UI | Core loop, offline, Bangla rendering | Flutter widget/integration tests, real device |
| Web UI | Screens, tables, role gating | Playwright/Cypress |
| Non-functional | Performance, security, backup | k6/JMeter, ZAP, restore drills |

**Definition of done:** all MVP acceptance cases (§27) pass, on a real low-end Android
device, before release.

## 3. Environments & data

- **Local**, **CI**, **Staging** (production-like, seeded), **Production**.
- Seed data from the DB seed (roles, plans, transaction_types, default Bangla template).
- Test tenants: at least two businesses to prove isolation. Synthetic customers only — no
  real PII in non-production.

## 4. Core correctness — the money math (highest priority)

| ID | Case | Expected |
|---|---|---|
| C-01 | Credit increases balance | balance += amount |
| C-02 | Payment decreases balance | balance −= amount |
| C-03 | balance = Σ(amount × balance_sign) | Always, incl. adjustments |
| C-04 | Overpayment blocked when disabled | `409 overpayment_not_allowed` |
| C-05 | Overpayment allowed when enabled | negative/advance balance, correct sign |
| C-06 | Reversal preserves original + links it | original intact; `reversal_of_transaction_id` set; audited |
| C-07 | Home total = Σ customer balances | Reconciles exactly |
| C-08 | FIFO allocation applies payment oldest-first | `payment_allocations` correct; aging = balance |
| C-09 | Aging buckets sum to outstanding after partial payment | Reconciles (regression for review fix H1) |
| C-10 | Aging uses business timezone | No off-by-one near Dhaka midnight (review fix M4) |

## 5. Database tests

| ID | Case | Expected |
|---|---|---|
| D-01 | DELETE a transaction | Rejected by `guard_transactions` |
| D-02 | UPDATE amount/type/customer/business on a transaction | Rejected (append-only) |
| D-03 | Duplicate `(business_id, device_id, local_id)` | Unique violation → idempotent handling |
| D-04 | RLS: query without business filter as app role | Only current business's rows returned |
| D-05 | RLS bypass attempt with wrong `app.current_business_id` | Zero rows |
| D-06 | RLS FORCE binds even the owner role | Isolation holds (review fix H2) |
| D-07 | `business_users` lookup by user before business chosen | Returns the user's memberships (login works, review fix H2) |
| D-08 | `customer_balances` / `customer_aging` views | Match hand-computed fixtures |

## 6. API integration tests

| ID | Case | Expected |
|---|---|---|
| A-01 | Register creates owner + business + tokens | `201`, role owner |
| A-02 | OTP request/verify issues tokens | `200`, device registered |
| A-03 | Expired access token | `401 token_expired`; refresh rotates |
| A-04 | Cross-tenant resource access | `403 cross_tenant_access` |
| A-05 | Insufficient role (e.g. sales rep records payment) | `403 insufficient_role` |
| A-06 | Replay `Idempotency-Key` on create | same record, `Idempotency-Replayed: true`, no dup |
| A-07 | Validation error envelope | `400 validation_failed` with per-field `details` |
| A-08 | Pagination/sort/filter server-side | correct `meta`, `limit` capped at 100 |
| A-09 | Reminder send without consent | `409 messaging_not_consented` |
| A-10 | Report export async flow | `202` → poll → signed URL |
| A-11 | Rate limit on `/auth/*` | `429 rate_limited` + `Retry-After` |

## 7. Android UI & offline tests

| ID | Case | Expected |
|---|---|---|
| M-01 | Full core loop offline (airplane mode) | add customer→credit→payment→balance→reminder all work |
| M-02 | Local search < 500ms, save < 1s, home < 2s | Meets §23 on low-end device |
| M-03 | Reconnect after offline creates | rows sync once; retries don't duplicate (M-03 ties C-08/D-03) |
| M-04 | Conflict surfaces in Sync Center | review screen shown; resolution audited |
| M-05 | Bangla conjunct rendering | correct on real ৳5–8k device (§33) |
| M-06 | Reminder opens SMS/WhatsApp with resolved variables | name + amount correct |
| M-07 | Entire core loop without reading English | passes (§27) |
| M-08 | First-run onboarding to first baki | < 3 minutes, no signup wall |

## 8. Web UI tests

| ID | Case | Expected |
|---|---|---|
| W-01 | Dashboard tiles & charts reconcile with API | figures match |
| W-02 | Role gating hides/disables controls | matches Web UI §5 table |
| W-03 | Reports run with each documented filter | correct rows; export works |
| W-04 | Customer statement opening/closing balance | reconciles |
| W-05 | Cannot view another business's data | enforced UI + API |

## 9. Security tests (§22)

- HTTPS-only; no secrets in source; JWT expiry/revocation; password hashing; input
  validation/sanitization; tenant isolation (RLS + API); rate limiting; audit completeness;
  encryption at rest where supported. Run an OWASP-style pass on auth, injection, and access
  control (IDOR across tenants especially).

## 10. Performance tests (§23)

- API p95 latency under expected load; report endpoints under large datasets (pagination
  holds); Android metrics on low-end hardware; DB index usage verified via `EXPLAIN` on the
  hot queries (business_id/customer_id/date filters).

## 11. Backup / restore & DR

- Scheduled backup runs; **restore drill** to a scratch instance verifies integrity and RLS;
  point-in-time recovery target documented; migration forward/rollback tested (§26).

## 12. MVP acceptance mapping (§27)

Every §27 criterion has at least one owning case: business+login (A-01), customer CRUD/
deactivate (W-*/M-*), offline credit/payment (M-01), balance correctness (C-03/C-07),
auto-sync on reconnect (M-03), duplicate-prevention on retry (A-06/D-03), history view
(M-*), dashboard totals (W-01), web reads central DB (W-05), tenant isolation (A-04/D-04),
correction audit trail (C-06). Release is blocked until all pass.

## 13. Payment allocation test fixtures

Concrete fixtures for the FIFO allocation logic (`reallocate_customer`, DB spec §13c; Offline
Sync §5). **Allocation and balance assertions are date-independent** and are the primary
checks; aging-bucket assertions use a test business with `timezone = 'UTC'` and `due_date`
set relative to `CURRENT_DATE`, so day-math is deterministic in CI.

### 13.1 Runnable template — F-ALLOC-01 (partial payment, oldest-first)

```sql
-- Preamble (once): a test user + business + customer. Seeded transaction_types are reused.
-- Run as the app role with app.current_business_id / app.current_user_id set (RLS, DB §14).
SET app.current_business_id = '00000000-0000-0000-0000-0000000000b1';
SET app.current_user_id     = '00000000-0000-0000-0000-0000000000u1';

INSERT INTO users (id, name, phone) VALUES
 ('00000000-0000-0000-0000-0000000000u1','Test Owner','01700000001');
INSERT INTO businesses (id, name, owner_user_id, timezone) VALUES
 ('00000000-0000-0000-0000-0000000000b1','Test Traders','00000000-0000-0000-0000-0000000000u1','UTC');
INSERT INTO customers (id, business_id, name) VALUES
 ('00000000-0000-0000-0000-0000000000k1','00000000-0000-0000-0000-0000000000b1','Test Customer');

-- GIVEN: three credits (oldest due first) + one partial payment  (b1/k1 shortened below)
INSERT INTO transactions (business_id, customer_id, transaction_type_code, amount, transaction_date, due_date) VALUES
 (:b1,:k1,'credit',20000, now()-interval '40 days', CURRENT_DATE-18),   -- C1
 (:b1,:k1,'credit',18000, now()-interval '30 days', CURRENT_DATE-10),   -- C2
 (:b1,:k1,'credit',12000, now()-interval  '5 days', CURRENT_DATE-1);    -- C3
INSERT INTO transactions (business_id, customer_id, transaction_type_code, amount, transaction_date) VALUES
 (:b1,:k1,'payment', 5000, now());                                      -- P1

-- ACTION
SELECT reallocate_customer(:b1, :k1);

-- EXPECT: P1 → C1 only, ৳5,000 (FIFO oldest-first)
SELECT c.amount AS credit_amt, pa.amount AS allocated
  FROM payment_allocations pa JOIN transactions c ON c.id = pa.credit_txn_id
 WHERE c.customer_id = :k1;
-- => exactly one row: (20000.00, 5000.00)

-- EXPECT: balance = 45000.00
SELECT balance FROM customer_balances WHERE customer_id = :k1;          -- 45000.00

-- EXPECT: aging buckets sum to the balance
SELECT bucket_0_7, bucket_8_30 FROM customer_aging WHERE customer_id = :k1;
-- => bucket_0_7 = 12000.00 (C3, 1d),  bucket_8_30 = 33000.00 (C1 15000 @18d + C2 18000 @10d)
```

Encode the remaining fixtures the same way (fresh customer id per fixture so they are
independent). The expected results below are the authoritative truth for each.

### 13.2 Fixture matrix (given → expected)

Notation: `Cn = amount @ −Dd` (credit, due D days ago); `Pn = amount` (payment); allocations
written `Pn→Cn: amount`.

| ID | Given | Action | Expected allocations | Balance | Aging (bucket = amount) |
|---|---|---|---|---|---|
| F-ALLOC-01 | C1 20000@−18, C2 18000@−10, C3 12000@−1; P1 5000 | reallocate | P1→C1: 5000 | 45000 | 0–7 = 12000; 8–30 = 33000 |
| F-ALLOC-02 | same credits; P1 25000 | reallocate | P1→C1: 20000; P1→C2: 5000 | 25000 | 0–7 = 12000; 8–30 = 13000 (C2) |
| F-ALLOC-03 | C1 20000@−18, C2 18000@−10; P1 15000 then P2 10000 | reallocate | P1→C1: 15000; P2→C1: 5000; P2→C2: 5000 | 13000 | 8–30 = 13000 (C2) |
| F-ALLOC-04 | C1 10000@−5; P1 15000 | reallocate | P1→C1: 10000 (5000 leftover **unallocated** = advance) | −5000 | none (0) |
| F-ALLOC-04b | …then add C2 8000@0; reallocate | reallocate | P1→C1: 10000; P1→C2: 5000 | 3000 | 0–7 = 3000 (C2) |
| F-ALLOC-05 | C1 20000@−18, C2 18000@−10; P1 15000; then **reverse C2** | reallocate | P1→C1: 15000 (C2 & its reversal excluded) | 5000 | 8–30 = 5000 (C1) |
| F-ALLOC-06 | C1 20000@−18; P1 20000; then **reverse P1** | reallocate | none (P1 & its reversal excluded) | 20000 | 8–30 = 20000 (C1 re-exposed) |
| F-ALLOC-07 | any of the above | run reallocate **twice** | identical rows; no duplicates | unchanged | unchanged |
| F-ALLOC-08 | C1 10000@−5; P1 10000 | reallocate | P1→C1: 10000 | 0 | none (0) |

### 13.3 Invariant assertion (run after every fixture)

The single acceptance check that must hold for **all** fixtures (maps to QA C-09):

```sql
-- aging buckets must sum to the (positive) balance for every customer
SELECT b.customer_id
  FROM customer_balances b
  LEFT JOIN customer_aging a ON a.customer_id = b.customer_id
 WHERE GREATEST(b.balance,0)
     <> COALESCE(a.bucket_0_7,0)+COALESCE(a.bucket_8_30,0)+COALESCE(a.bucket_31_60,0)
       +COALESCE(a.bucket_61_90,0)+COALESCE(a.bucket_90_plus,0);
-- => zero rows.  (Negative balances are advances and are expected to have no aging.)
```

### 13.4 Notes for implementers

- Reverse fixtures (05/06) post the opposite-direction adjustment with
  `reversal_of_transaction_id` set, then call `reallocate_customer`; no special allocation
  code is needed (the function ignores reversed txns).
- F-ALLOC-07 proves idempotency — the function is delete-and-recompute, so re-running never
  duplicates rows. Concurrency (two payments at once) is covered by the per-customer advisory
  lock; test with parallel transactions and assert the invariant in §13.3 still holds.
- Credits are expected to carry a `due_date` (from the customer's `default_due_days`). A
  credit with no `due_date` does not age by design, so the §13.3 invariant can legitimately
  differ by that unaged amount — ensure writes set a due date. All fixtures above set one.
- Wire these into the DB test layer (pgTAP or SQL fixtures per QA §2); cases C-08, C-09, C-10
  in §4 are satisfied by this fixture set.
