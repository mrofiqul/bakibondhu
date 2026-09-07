# 04 · Data Model

Two tables. That is the whole thing. **Store transactions, never store a
balance — always compute it.**

## 4.1 Entities

### `customer` (party)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID / text | yes | Primary key. Generated on device. |
| `name` | text | yes | Non-empty after trim. Duplicates allowed. |
| `phone` | text | no | Stored as typed. Needed for reminders. |
| `created_at` | timestamp | yes | Device local time at creation. |

### `transaction`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | UUID / text | yes | Primary key. |
| `customer_id` | UUID / text | yes | Foreign key → `customer.id`. |
| `type` | enum | yes | `credit` (বাকি দিলাম) or `payment` (টাকা পেলাম). |
| `amount` | decimal | yes | Always **> 0**; sign is implied by `type`, never stored negative. |
| `note` | text | no | Short free text (e.g. "চাল, ডাল"). |
| `date` | date | yes | The business date of the transaction. Defaults to today; editable. |
| `created_at` | timestamp | yes | Immutable audit time; may differ from `date`. |

That is the entire schema for v1. No `balance` column exists anywhere.

## 4.2 Computed values

```
customer_balance(c) = Σ amount WHERE type = 'credit'   AND customer_id = c
                    − Σ amount WHERE type = 'payment'   AND customer_id = c

total_owed          = Σ customer_balance(c) FOR ALL c WHERE customer_balance(c) > 0
```

- **DM-3** A customer balance is `credits − payments`. Positive = they owe the
  merchant; zero = settled; negative = merchant holds advance / overpayment.
- **DM-4** `total_owed` (Home headline) sums **only positive** balances.
  Negative balances are **not** netted into the headline — a customer's advance
  does not reduce what the whole market owes you.

## 4.3 Integrity & business rules

- **DM-1** `amount` is always stored as a positive number. The `type` field —
  not the sign — determines direction. This keeps the ledger unambiguous.
- **DM-2** `phone` has **no** format validation in v1 (Bangladeshi numbers vary;
  merchants paste as they know them). Reminder actions simply require the field
  to be non-empty. Normalization is deferred.
- **DM-5 (append-only)** Transactions are **never edited or deleted** in v1.
  History is immutable. A mistake is corrected by adding a **reversing
  transaction** of the opposite type and equal amount. This guarantees the
  numbers can never silently drift and gives a truthful audit trail.
- **DM-6** Deleting a customer is **out of scope** in v1 (would orphan history and
  invite accidental data loss). If demanded later, model it as soft-delete/archive,
  never a hard delete of transactions.
- **DM-7** Aging (e.g. "১২ দিন পার") is derived at read time from transaction
  `date`s, not stored. Definition to finalize in design — recommended: days since
  the **oldest unsettled credit** contributing to the current positive balance.

## 4.4 Indexing & performance

- Index `transaction(customer_id)` — balances are computed per customer
  constantly.
- Index `transaction(date)` — supports history ordering and aging.
- For Home, maintain either (a) a per-customer running-total **view/query** or
  (b) an in-memory cache recomputed on write. Either is fine; the **source of
  truth remains the transaction log** ([NFR-2](06-non-functional.md) covers the
  performance target).

## 4.5 Storage & sync

- v1 persists locally in **SQLite** (offline-first). See
  [07-architecture](07-architecture.md).
- Schema is designed to be **sync-friendly later**: UUID keys (no
  auto-increment collisions across devices), append-only transactions (trivial
  to merge), and `created_at` timestamps. Cloud sync is **not** built in v1.

## 4.6 Entity relationship

```
┌───────────────┐        1     ∞   ┌────────────────────┐
│   customer     │──────────────────│    transaction      │
│───────────────│                   │────────────────────│
│ id (PK)        │                   │ id (PK)             │
│ name           │                   │ customer_id (FK)    │
│ phone?         │                   │ type: credit|payment│
│ created_at     │                   │ amount (>0)         │
└───────────────┘                   │ note?               │
                                     │ date                │
     balance = Σcredit − Σpayment    │ created_at          │
     (computed, never stored)        └────────────────────┘
```
