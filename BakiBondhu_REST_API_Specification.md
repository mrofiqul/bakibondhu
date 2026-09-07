# BakiBondhu — REST API Specification

**Version 1.0** · Companion to the Application Specification (v1.1) and PostgreSQL Schema (v1.0)
Target backend: ASP.NET Core Web API · JSON over HTTPS · JWT auth

---

## 1. Conventions

| Item | Value |
|---|---|
| Base URL | `https://api.bakibondhu.com` |
| Version prefix | `/api/v1` (versioned per Section 21) |
| Format | `Content-Type: application/json; charset=utf-8` |
| Auth | `Authorization: Bearer <access_token>` (JWT) |
| Active business | `X-Business-Id: <uuid>` (required for multi-business users; validated against membership) |
| IDs | UUID (strings) |
| Money | JSON number, 2-decimal (BDT). Clients MUST treat as fixed-decimal, not float. |
| Timestamps | ISO-8601 UTC, e.g. `2026-09-07T09:30:00Z` (displayed to users in Asia/Dhaka) |
| Idempotency | `Idempotency-Key: <uuid>` on all POSTs that create financial data |

### Tenancy
Every request is scoped to one business. `business_id` comes from the JWT (single-business users) or the `X-Business-Id` header (multi-business users). The server rejects any resource not owned by that business with `403 forbidden` (Section 5). No response ever contains another business's data.

### Standard error envelope
All non-2xx responses share one shape (Section 21):

```json
{
  "error": {
    "code": "validation_failed",
    "message": "One or more fields are invalid.",
    "details": [
      { "field": "amount", "message": "Amount must be greater than 0." }
    ],
    "trace_id": "b1f2c3d4-0000-4a11-9c22-abc123def456"
  }
}
```

| HTTP | `error.code` examples |
|---|---|
| 400 | `validation_failed`, `malformed_request` |
| 401 | `unauthenticated`, `token_expired` |
| 403 | `forbidden`, `cross_tenant_access`, `insufficient_role` |
| 404 | `not_found` |
| 409 | `conflict`, `idempotency_replay`, `overpayment_not_allowed` |
| 422 | `business_rule_violation` |
| 429 | `rate_limited` |
| 500 | `internal_error` |

### List envelope & pagination
List endpoints return `data` + `meta`. Pagination is `page` + `limit` (max 100); large reports use the same mechanism (Section 23).

```json
{
  "data": [ /* ...items... */ ],
  "meta": { "page": 1, "limit": 50, "total": 128, "has_more": true }
}
```

Common list query params: `?page=`, `?limit=`, `?sort=` (e.g. `-balance`, `name`, `-overdue_days`), plus per-resource filters. Server-side filtering & sorting only (Section 21).

---

## 2. Authentication — `/api/v1/auth`

### POST `/auth/register`
Creates the owner user **and** their business in one call (Section 25 MVP acceptance criterion).

Request:
```json
{
  "name": "Rafiq",
  "phone": "01712345678",
  "password": "••••••••",
  "business_name": "Rafiq Traders",
  "area": "Mirpur"
}
```
`201 Created`:
```json
{
  "user": { "id": "9c1e...", "name": "Rafiq", "phone": "01712345678" },
  "business": { "id": "5a7b...", "name": "Rafiq Traders", "timezone": "Asia/Dhaka", "currency": "BDT" },
  "role": "owner",
  "tokens": {
    "access_token": "eyJhbGciOi...",
    "refresh_token": "def502...",
    "access_expires_in": 900
  }
}
```

### POST `/auth/otp/request` → POST `/auth/otp/verify`
Phone-first login for field users (Section 38).

`/auth/otp/request` → `200 OK`:
```json
{ "phone": "01712345678", "otp_sent": true, "expires_in": 120 }
```
`/auth/otp/verify`:
```json
{ "phone": "01712345678", "otp": "483920", "device_identifier": "android-6f2a...", "platform": "android" }
```
→ `200 OK` returns the same `tokens` object as register, plus `device_id`.

### POST `/auth/login` (password)
```json
{ "identifier": "01712345678", "password": "••••••••" }
```

### POST `/auth/refresh`
```json
{ "refresh_token": "def502..." }
```
→ new `access_token` (and rotated `refresh_token`). `401 token_expired` if the refresh token is invalid/expired.

### POST `/auth/logout`
Revokes the presented refresh token. `204 No Content`.

---

## 3. Business & Users — `/api/v1/business`, `/api/v1/users`

- `GET /business` — current business profile & settings.
- `PATCH /business` — update name, area, address, settings (role: owner/manager).
- `GET /users` — members of the business (`data`+`meta`).
- `POST /users` — invite/add a member with a role (owner only).
- `PATCH /users/{id}` — change role or status.

`POST /users`:
```json
{ "name": "Karim", "phone": "01811112222", "role": "collection_officer" }
```
`403 insufficient_role` if the caller is not an owner.

---

## 4. Customers — `/api/v1/customers`

### GET `/customers`
Filters: `search` (name/phone/code), `status` (`outstanding|paid|overdue|due_today`), `area`, `sales_rep_id`, `sort` (`-balance` default).

`GET /api/v1/customers?status=overdue&sort=-balance&page=1&limit=2`
```json
{
  "data": [
    {
      "id": "c-1001", "name": "করিম স্টোর", "phone": "01712345678",
      "area": "Mirpur", "customer_type": "grocery",
      "balance": 45000.00, "overdue_amount": 45000.00, "overdue_days": 12,
      "is_active": true
    },
    {
      "id": "c-1002", "name": "রহিম ট্রেডার্স", "phone": "01822223333",
      "balance": 28500.00, "overdue_amount": 12000.00, "overdue_days": 4,
      "is_active": true
    }
  ],
  "meta": { "page": 1, "limit": 2, "total": 18, "has_more": true }
}
```

### POST `/customers`
```json
{
  "name": "করিম স্টোর",
  "phone": "01712345678",
  "area": "Mirpur",
  "customer_type": "grocery",
  "credit_limit": 100000.00,
  "default_due_days": 30,
  "messaging_consent": true,
  "local_id": "loc-8843",
  "device_id": "android-6f2a..."
}
```
`201 Created` returns the full customer including server `id`. If `local_id` was already synced, returns `200 OK` with the existing record (idempotent, Section 40 duplicate guard).

### GET `/customers/{id}`
Returns profile + computed rollups from the `customer_balances` view:
```json
{
  "id": "c-1001", "name": "করিম স্টোর", "phone": "01712345678",
  "balance": 45000.00, "total_credit": 63000.00, "total_paid": 18000.00,
  "overdue_amount": 45000.00, "oldest_due_date": "2026-08-20",
  "credit_limit": 100000.00, "default_due_days": 30,
  "messaging_consent": true, "do_not_message": false, "is_active": true
}
```

### PATCH `/customers/{id}` · POST `/customers/{id}/deactivate`
Update editable fields; deactivate sets `is_active=false` (customers are never hard-deleted).

---

## 5. Transactions — `/api/v1/transactions`

> Append-only. There is **no DELETE and no amount edit** — corrections use a reversal (Section 15). All create calls require `Idempotency-Key`.

### POST `/transactions` — record credit (baki)
```json
{
  "customer_id": "c-1001",
  "type": "credit",
  "amount": 12000.00,
  "transaction_date": "2026-09-06T10:15:00Z",
  "due_date": "2026-10-06",
  "note": "চাল, ডাল",
  "invoice_reference": "INV-3391",
  "local_id": "loc-txn-5501",
  "device_id": "android-6f2a..."
}
```
`201 Created`:
```json
{
  "id": "t-9001", "local_id": "loc-txn-5501", "customer_id": "c-1001",
  "type": "credit", "amount": 12000.00, "due_date": "2026-10-06",
  "customer_balance_after": 45000.00,
  "sync_status": "SYNCED", "created_at": "2026-09-06T10:15:02Z"
}
```
Replaying the same `Idempotency-Key` (or `local_id`) returns the **same** record with `200 OK` and header `Idempotency-Replayed: true` — never a duplicate (Section 21/27).

### POST `/transactions` — record payment
```json
{ "customer_id": "c-1001", "type": "payment", "amount": 5000.00,
  "payment_method": "cash", "local_id": "loc-txn-5502", "device_id": "android-6f2a..." }
```
If the payment would exceed the outstanding balance and the business hasn't enabled overpayment, `409 overpayment_not_allowed` (Section 15). Otherwise `201` with `customer_balance_after`.

### POST `/transactions/{id}/reverse` — correct a mistake
```json
{ "reason": "Wrong amount entered", "local_id": "loc-txn-5510", "device_id": "android-6f2a..." }
```
Posts an opposite-direction `adjustment_credit`/`adjustment_debit` row linked via `reversal_of_transaction_id`; the original stays intact (audited). `201 Created`.

### GET `/transactions?customer_id=c-1001&sort=-transaction_date`
Returns the customer's ledger (`data`+`meta`), newest first.

### Payment allocation (aging)
On every payment, credit, and reversal, the server runs FIFO **payment allocation** in the
same transaction (`reallocate_customer`, DB spec §13c) so `/receivables/aging` reflects the
*unpaid* portion of each credit and reconciles with the balance. This is server-authoritative
and invisible to the client, which only records the transaction. See the Offline Sync
Technical Design §5.

---

## 6. Receivables — `/api/v1/receivables`

- `GET /receivables/summary` — totals for the business.
- `GET /receivables/aging` — from the `customer_aging` view.
- `GET /receivables/priorities` — collection-priority-ranked customers (Section 10).

`GET /receivables/aging?customer_id=c-1001`:
```json
{
  "customer_id": "c-1001",
  "buckets": { "0_7": 0.00, "8_30": 12000.00, "31_60": 18000.00, "61_90": 15000.00, "90_plus": 0.00 },
  "total_outstanding": 45000.00
}
```

`GET /receivables/priorities?limit=3`:
```json
{
  "data": [
    { "customer_id": "c-1001", "name": "করিম স্টোর", "balance": 45000.00, "overdue_days": 12,
      "broken_promises": 1, "priority_score": 87 }
  ],
  "meta": { "page": 1, "limit": 3, "total": 9, "has_more": true }
}
```
> `priority_score` combines outstanding amount, overdue duration, payment behaviour and promise history. The formula is configurable in a later release (Section 10).

---

## 7. Collections — `/api/v1/collections`

### POST `/collections`
```json
{
  "customer_id": "c-1001",
  "method": "phone",
  "status": "promise_to_pay",
  "note": "Will pay ৳20,000 on Friday",
  "next_follow_up_at": "2026-09-12",
  "local_id": "loc-act-3001", "device_id": "android-6f2a..."
}
```
`201 Created`. `status` is one of the `collection_status` enum values (Section 8.8). `GET /collections?customer_id=` lists activity history.

---

## 8. Promise-to-Pay — `/api/v1/promises`

### POST `/promises`
```json
{ "customer_id": "c-1001", "promised_amount": 20000.00, "promise_date": "2026-09-12", "follow_up_date": "2026-09-13" }
```

### PATCH `/promises/{id}`
```json
{ "status": "partial", "actual_payment": 8000.00 }
```
`status` ∈ `open|fulfilled|partial|broken` (Section 8.9). `GET /promises?status=broken` powers the "Broken Promises" dashboard tile.

---

## 9. Reminders — `/api/v1/reminders`

- `GET /reminders/templates` · `POST /reminders/templates` · `PATCH /reminders/templates/{id}`
- `POST /reminders/send` — send a reminder (Sections 9 & 34).
- `GET /reminders/logs?customer_id=` — delivery history.

`POST /reminders/send`:
```json
{
  "customer_id": "c-1001",
  "template_id": "tmpl-bn-01",
  "channel": "sms"
}
```
Server resolves the template variables from live data and enforces consent:
`201 Created`:
```json
{
  "id": "rl-7742", "customer_id": "c-1001", "channel": "sms",
  "to_number": "01712345678",
  "message_snapshot": "আসসালামু আলাইকুম করিম ভাই। আপনার কাছে Rafiq Traders-এ ৳45,000 বাকি আছে। সুবিধামতো পরিশোধ করলে উপকৃত হতাম। ধন্যবাদ।",
  "status": "queued", "cost": 0.35, "created_at": "2026-09-07T09:31:00Z"
}
```
`409 conflict` with `error.code = "messaging_not_consented"` if the customer has `do_not_message=true` or no consent (Section 34). Delivery status later moves `queued → sent → delivered|failed` via the gateway webhook.

---

## 10. Reports — `/api/v1/reports`

`GET /reports/{type}` where `type` ∈ `customer_statement, outstanding, aging, collection, credit_sales, customer_receivable, salesperson_collection, daily_collection, monthly_credit_vs_collection, promise_performance` (Section 13).

Shared filters: `date_from`, `date_to`, `customer_id`, `sales_rep_id`, `area`, `status`, `aging_bucket`. Reports paginate server-side.

`GET /reports/customer_statement?customer_id=c-1001&date_from=2026-08-01&date_to=2026-09-07`:
```json
{
  "customer": { "id": "c-1001", "name": "করিম স্টোর" },
  "period": { "from": "2026-08-01", "to": "2026-09-07" },
  "opening_balance": 0.00,
  "lines": [
    { "date": "2026-08-20", "type": "credit",  "amount": 20000.00, "balance": 20000.00 },
    { "date": "2026-08-28", "type": "credit",  "amount": 18000.00, "balance": 38000.00 },
    { "date": "2026-09-02", "type": "payment", "amount": 5000.00,  "balance": 33000.00 },
    { "date": "2026-09-06", "type": "credit",  "amount": 12000.00, "balance": 45000.00 }
  ],
  "closing_balance": 45000.00
}
```

### POST `/reports/{type}/export`
```json
{ "format": "pdf", "filters": { "date_from": "2026-08-01", "date_to": "2026-09-07" } }
```
`202 Accepted` → `{ "export_id": "exp-55", "status": "processing" }`; poll `GET /reports/exports/exp-55` for a signed download URL. `format` ∈ `excel|csv|pdf` (Section 13).

---

## 11. Dashboard — `/api/v1/dashboard`

`GET /dashboard` (web) / `GET /dashboard/home` (Android):
```json
{
  "total_receivable": 124500.00,
  "overdue_amount": 73000.00,
  "due_today": 6000.00,
  "collected_today": 8000.00,
  "customers_with_outstanding": 18,
  "collection_rate": 0.62,
  "top_priorities": [
    { "customer_id": "c-1001", "name": "করিম স্টোর", "balance": 45000.00, "overdue_days": 12 }
  ]
}
```
`collection_rate` is a fraction (0.62 = 62%). All figures are business-scoped.

---

## 12. Sync — `/api/v1/sync`

Powers offline-first Android (Sections 16–17). Two endpoints: **push** local changes, **pull** server changes.

### POST `/sync/push`
Batch of locally-created records. Each carries a `local_id`; the server is idempotent on `(business_id, device_id, local_id)`.
```json
{
  "device_id": "android-6f2a...",
  "changes": [
    { "entity": "customer",    "local_id": "loc-8843",     "op": "create",
      "data": { "name": "করিম স্টোর", "phone": "01712345678" } },
    { "entity": "transaction", "local_id": "loc-txn-5501", "op": "create",
      "data": { "customer_local_id": "loc-8843", "type": "credit", "amount": 12000.00, "due_date": "2026-10-06" } }
  ]
}
```
`200 OK` — per-item result mapping `local_id → server_id` and a status:
```json
{
  "results": [
    { "local_id": "loc-8843",     "server_id": "c-1001", "entity": "customer",    "sync_status": "SYNCED" },
    { "local_id": "loc-txn-5501", "server_id": "t-9001", "entity": "transaction", "sync_status": "SYNCED" }
  ],
  "server_time": "2026-09-07T09:35:00Z"
}
```
Conflict example (a record changed on the server since the device last pulled):
```json
{ "local_id": "loc-txn-5599", "entity": "transaction", "sync_status": "CONFLICT",
  "reason": "duplicate_local_id_different_amount",
  "server_record": { "id": "t-9050", "amount": 12000.00 } }
```
Financial records are append-only, so conflicts are surfaced for review, never silently overwritten (Section 17/37). Failed items return `sync_status: "FAILED"` with an `error`.

### GET `/sync/pull?since=<ISO-8601>&device_id=...`
Returns everything in the business changed after `since` (customers, transactions, collections, promises), so the device can update its SQLite store:
```json
{
  "customers":    [ { "id": "c-1001", "updated_at": "2026-09-07T09:35:00Z", "…": "…" } ],
  "transactions": [ { "id": "t-9001", "updated_at": "2026-09-07T09:35:02Z", "…": "…" } ],
  "collections":  [],
  "promises":     [],
  "server_time":  "2026-09-07T09:40:00Z",
  "has_more":     false
}
```
The client stores `server_time` and passes it as the next `since` (cursor).

---

## 13. Subscriptions — `/api/v1/subscriptions`

- `GET /subscriptions/plans` — available plans & prices.
- `GET /subscriptions` — the business's current plan & status.
- `POST /subscriptions/change` — `{ "plan_code": "pro" }`.

`GET /subscriptions`:
```json
{
  "plan": { "code": "pro", "name": "Pro", "price_monthly": 249.00, "currency": "BDT" },
  "status": "active",
  "current_period_end": "2026-10-07T00:00:00Z"
}
```

---

## 14. Cross-cutting requirements (Section 21/22)

- **JWT** access (~15 min) + refresh (rotating); revocation on logout.
- **RBAC** enforced per endpoint by role (owner/manager/sales_rep/collection_officer/sysadmin).
- **Rate limiting** on `/auth/*` and any public endpoint → `429 rate_limited` with `Retry-After`.
- **Idempotency** required on financial POSTs; server stores the key + response for 24h and replays it.
- **Audit**: every create/update/reverse and every auth event writes an `audit_logs` row (who, what, before/after).
- **Validation**: consistent `validation_failed` envelope with per-field `details`.
- **Pagination/filtering/sorting**: server-side only; `limit` capped at 100.
- **Versioning**: breaking changes ship under `/api/v2`; `/api/v1` stays stable.

---

*End of REST API Specification v1.0. Next companion documents (per Section 32): Android & Web UI/UX specs, Offline Sync Technical Design, QA/Test-Case spec, and Deployment/DevOps spec.*
