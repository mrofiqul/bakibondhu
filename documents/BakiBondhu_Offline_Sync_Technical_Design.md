# BakiBondhu — Offline Synchronization Technical Design

**Version 1.0** · Companion to the Application Specification (v1.1), DB Spec (v1.0), REST API (v1.0)
Implements app-spec §16–17 and §37. Android is the offline field client; PostgreSQL is authoritative.

---

## 1. Goals & principles

- The Android core loop works fully offline (§16); the server is the authoritative store
  for synchronized data (§29).
- **Financial data is append-only** (§15) — this is what makes sync safe: transactions are
  immutable events, so syncing is "insert once," not "merge mutable state."
- **Never silently overwrite** a financial record; conflicts are surfaced for review (§37).
- **Idempotent** by construction: a client transaction lands exactly once even across
  retries, duplicate submits, or app restarts (§21/§27).
- The local Android DB is a working store, not the permanent source of truth (§29).

## 2. Identity model

| Concept | Field(s) | Notes |
|---|---|---|
| Client id | `local_id` (UUID) | Generated on-device at creation; stable across retries. |
| Server id | `id` (UUID) | Assigned by the server; UUIDs mean no cross-device collisions. |
| Device | `device_id` | Registered per user+device (`devices` table). |
| Dedup key | `(business_id, device_id, local_id)` | DB `UNIQUE` on transactions → idempotency. |
| Request key | `Idempotency-Key` header | Covers web (which has no device/local id) + belt-and-suspenders for Android. |

The server stores each `Idempotency-Key` + response for 24h and replays it (API §14).

## 3. Local store (Android SQLite)

- Mirrors the synced entities: `customers`, `transactions`, `collection_activities`,
  `promise_to_pay` (+ minimal lookup copies of `transaction_types`, templates).
- Every syncable row carries: `local_id`, `server_id?`, `sync_status`, `device_id`,
  `created_at`, `updated_at`.
- **Balances are computed locally** the same way the server does — `Σ amount × balance_sign`
  — so offline balances match the server's `customer_balances` view exactly (§15).
- An **outbox** table (or a `sync_status` index) tracks unsynced rows: `LOCAL → PENDING →
  SYNCED / FAILED / CONFLICT` (§17).

## 4. Sync engine

### 4.1 Triggers
- Automatic background sync when connectivity returns (§16), on app foreground, and after
  each successful local write (debounced).
- Manual **Sync Now** in the Sync Center.

### 4.2 Push — upload local changes (`POST /sync/push`)
1. Collect rows where `sync_status IN (LOCAL, PENDING, FAILED)`, ordered so dependencies
   come first (customer before its transactions). References use `customer_local_id` when
   the customer isn't yet server-assigned.
2. Send a batch with `device_id` and a `changes[]` array (each carries `local_id`, `entity`,
   `op`, `data`).
3. Server processes each item idempotently on `(business_id, device_id, local_id)` and
   returns a per-item result mapping `local_id → server_id` + `sync_status`.
4. Client updates local rows: store `server_id`, set `SYNCED`, or record `FAILED`/`CONFLICT`.

### 4.3 Pull — download server changes (`GET /sync/pull?since=<cursor>&device_id=`)
1. Client sends the last `server_time` cursor it stored.
2. Server returns everything in the business changed after `since` (customers, transactions,
   collections, promises) plus a new `server_time` and `has_more`.
3. Client upserts into SQLite by `server_id`; pages until `has_more = false`; stores the new
   cursor. Pulled financial rows are inserted, not merged (they're immutable).

### 4.4 Ordering & dependencies
- Push customers before transactions; resolve `customer_local_id → server_id` server-side in
  the same batch. Payments reference their customer, not specific credits, at sync time;
  allocation (below) runs server-side after the payment is persisted.

## 5. Payment allocation (FIFO)

Aging must reflect the **unpaid** portion of each credit, so payments are applied to a
customer's outstanding credits **oldest-due first**. Allocation is **server-authoritative** —
the offline client only records the payment; the server allocates. This keeps one source of
truth for aging and avoids the client guessing.

### 5.1 Model & vocabulary

| Term | Definition |
|---|---|
| **Increasing txn** | `balance_sign = +1`: `credit`, `adjustment_debit` — a receivable that can be settled. |
| **Reducing txn** | `balance_sign = −1`: `payment`, `adjustment_credit` — settles increasing txns. |
| **Active txn** | Not a reversal entry (`reversal_of_transaction_id IS NULL`) **and** not itself reversed. |
| **Outstanding(C)** | `C.amount − Σ payment_allocations.amount WHERE credit_txn_id = C.id`. |

**Invariant (what the whole thing guarantees):** for every customer,
`Σ customer_aging.buckets  =  customer_balances.balance` — as long as allocation has run.
Balances themselves never depend on allocation (`balance = Σ amount × balance_sign`); the
table only *attributes* payments to credits for aging.

### 5.2 Algorithm — deterministic recompute per customer

Rather than patch allocations incrementally, the server **recomputes a customer's allocations
from scratch** whenever anything relevant changes. It is idempotent and easy to reason about:

```
reallocate_customer(business_id, customer_id):
    lock the customer (serialize concurrent payments)
    delete all payment_allocations for this customer's credits
    inc = active increasing txns, ordered by (due_date asc NULLS LAST, created_at, id),
          each with remaining = amount
    for pay in active reducing txns, ordered by (created_at, id):
        left = pay.amount
        for C in inc where C.remaining > 0 (in order):
            if left <= 0: break
            take = min(left, C.remaining)
            insert payment_allocations(payment_txn_id=pay.id, credit_txn_id=C.id, amount=take)
            C.remaining -= take
            left -= take
        # left > 0 here  => advance / overpayment, intentionally left unallocated
```

The reference implementation ships in the schema as the PL/pgSQL function
`reallocate_customer(business_id, customer_id)` (DB spec §13c), which also takes a
`pg_advisory_xact_lock` on the customer to prevent two concurrent payments double-allocating.
Equivalent logic may live in the .NET domain layer calling the same SQL — but the function is
the single authoritative definition.

### 5.3 When it runs (trigger points)

Call `reallocate_customer(business_id, customer_id)` **in the same DB transaction** as:

| Event | Endpoint | Why |
|---|---|---|
| Payment created | `POST /transactions` (payment) & `/sync/push` | apply the new payment |
| Credit created | `POST /transactions` (credit) & `/sync/push` | absorb any prior advance/overpayment onto the new credit |
| Reversal posted | `POST /transactions/{id}/reverse` | drop the reversed credit from aging / re-expose credits a reversed payment had settled |

Because it is idempotent, running it more than once is harmless; running it in the same
transaction as the insert keeps allocation atomic with the write.

### 5.4 Reversal behavior (handled automatically)

Reversals need no special allocation code — because `reallocate_customer` only considers
**active** txns, a fresh recompute does the right thing:

- **Reverse a credit** (post `adjustment_credit`, `reversal_of = C`): C and its reversal both
  become inactive → C leaves aging, and any payments that were on C are freed and re-applied
  FIFO to the next-oldest outstanding credits.
- **Reverse a payment** (post `adjustment_debit`, `reversal_of = P`): P and its reversal both
  become inactive → the credits P had settled become outstanding again (and overdue again).

Balances stay correct throughout (the append-only pair nets to zero). Every reversal already
writes an `audit_logs` row (§15/§22).

### 5.5 Overpayment / advance

If a payment exceeds all outstanding credit, the leftover stays **unallocated** — the
customer's balance goes negative (an advance), and aging shows nothing outstanding. When the
next credit is created, the credit-created trigger point re-runs allocation and the advance is
applied to it automatically.

### 5.6 Worked example

Credits `C1 ৳20,000` (due 08-20), `C2 ৳18,000` (due 08-28), `C3 ৳12,000` (due 09-06);
payment `P1 ৳5,000` (09-02). After `reallocate_customer`:

- `P1 → C1` for ৳5,000 → C1 outstanding ৳15,000; C2 ৳18,000; C3 ৳12,000.
- **Balance** = 20,000 + 18,000 + 12,000 − 5,000 = **৳45,000**.
- **Aging** (as of 09-07): C1 15,000 (18d → 8–30) · C2 18,000 (10d → 8–30) · C3 12,000
  (1d → 0–7). Buckets total **৳45,000 = balance.** ✔ reconciles.

### 5.7 Correctness & tests

Covered by QA cases C-08 (FIFO applies oldest-first), C-09 (aging reconciles after partial
payment), and C-10 (business-timezone overdue). The recompute is O(credits + payments) per
customer; if a single customer accumulates very large history, switch to an incremental
allocation keyed on the new txn — the invariant in §5.1 is the acceptance test either way.

## 6. Conflict handling (§37)

The append-only model makes true conflicts rare. Defined cases:

| Case | Detection | Resolution |
|---|---|---|
| **Duplicate submit** (same `local_id`, same data) | Unique key hit | Return the existing row, `Idempotency-Replayed: true`. Not a conflict. |
| **Duplicate `local_id`, different amount** | Unique key hit, payload differs | `CONFLICT`; surfaced in the Sync Center review screen; never overwrites. User confirms keep/repost as a new record. |
| **Edit to an immutable field** | DB trigger `guard_transactions` rejects | Client must post a reversal/adjustment instead; shown as an error, not a silent drop. |
| **Stale customer edit** | `updated_at` compare on pull | Last-write-wins is acceptable for *non-financial* customer fields only; financial rows never LWW. |

Every conflict resolution writes an `audit_logs` row (§15/§22).

## 7. Failure, retry & safety

- **Retries** use exponential backoff; because writes are idempotent, retrying is always safe.
- **Partial batch:** per-item results mean a batch can partly succeed; failed items stay
  `FAILED` and are retried next cycle.
- **Durability:** every local write is committed to SQLite before the UI confirms success; no
  transaction is lost across app restart or update (§27 / NFR data safety).
- **Clock:** timestamps stored UTC (`timestamptz`); "today"/overdue computed in the business
  timezone (Asia/Dhaka) server-side. Devices never rely on local clock for aging.
- **Forced update (§41):** a schema/sync-breaking release requires a minimum client version;
  the server rejects incompatible `/sync` calls with a clear upgrade instruction.

## 8. Security during sync (§22)

- Every `/sync` call is JWT-authenticated and business-scoped; RLS enforces tenant isolation
  even if a query forgets its filter. The app connects as a non-owner role so RLS binds.
- A device only ever pulls its own business's data; `X-Business-Id`/JWT decides the tenant.

## 9. Test hooks (see QA spec)

- Offline create → reconnect → single server row (no duplicate) on retry.
- Two devices create the same customer → both resolve without cross-linking wrong rows.
- Payment offline then sync → correct FIFO allocation and reconciled aging.
- Conflict path surfaces in the review screen and audits the resolution.
