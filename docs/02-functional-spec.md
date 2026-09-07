# 02 · Functional Specification

## 2.1 The core loop

Everything in the app serves these five steps. Build them in this order; each
must feel instant.

```
add → owe → pay → check → nudge   → then repeat, every day
 1     2     3      4        5
```

| Step | Action | Bangla |
|------|--------|--------|
| 1 | Add a customer | পার্টি |
| 2 | Record credit | বাকি দিলাম |
| 3 | Record payment | টাকা পেলাম |
| 4 | See balance | কত বাকি |
| 5 | Send reminder | মনে করান |

If a requirement below does not serve this loop, it does not belong in v1.

---

## 2.2 Functional requirements

### FR-1 · Add a customer (party)

- **FR-1.1** The merchant can create a customer with a **name** (required) and a
  **phone number** (optional, but visibly encouraged).
- **FR-1.2** No other field is collected — no address, no photo, no category, no
  email. Deliberately.
- **FR-1.3** Name must be non-empty after trimming whitespace. Phone, if entered,
  is stored as typed (no format enforcement in v1) — see [DM-2](04-data-model.md).
- **FR-1.4** On save, the app returns to the context the merchant came from
  (Home, or the add-transaction flow if adding a customer inline).
- **FR-1.5** Duplicate names are **allowed** (two customers can share a name); the
  merchant disambiguates. v1 does not merge or warn.

### FR-2 · Record a credit — বাকি দিলাম

- **FR-2.1** Against a selected customer, the merchant records a **credit**
  transaction with an **amount** (required, > 0).
- **FR-2.2** Optional fields: a short **note** (e.g. "চাল, ডাল") and a **date**
  (defaults to today; editable).
- **FR-2.3** Saving increases that customer's balance and the global total owed.
- **FR-2.4** Amount entry uses a large numeric keypad (see [03-screens](03-screens.md),
  Screen 3). No decimal paisa required, but decimals are permitted.

### FR-3 · Record a payment — টাকা পেলাম

- **FR-3.1** Against a selected customer, the merchant records a **payment**
  transaction with an **amount** (required, > 0), optional note and date.
- **FR-3.2** Saving decreases that customer's balance and the global total owed.
- **FR-3.3** A payment **may drive a balance to zero or negative** (customer
  overpaid / has advance credit). v1 shows the true signed balance; it does not
  block overpayment. Negative balances render distinctly (e.g. "আপনি দেবেন" /
  advance) — copy finalized in design.

### FR-4 · See balances

- **FR-4.1 (per customer)** The customer-detail screen shows the current balance
  at the top, computed as Σ credits − Σ payments for that customer ([DM-3](04-data-model.md)).
- **FR-4.2 (total)** The Home screen shows **one big number**: the total owed to
  the merchant = the sum of all **positive** customer balances ([DM-4](04-data-model.md)).
- **FR-4.3** Balances are **always computed from transactions, never stored.**
- **FR-4.4** The Home list is sorted by amount owed, biggest / oldest first, so
  the money that matters most is on top.
- **FR-4.5** Each Home row shows customer name, balance, and an **aging** hint
  (e.g. "১২ দিন পার") derived from the oldest unsettled activity.
- **FR-4.6** Home shows a customer count (e.g. "১৮ জন কাস্টমার").

### FR-5 · Send a reminder — মনে করান

- **FR-5.1** From a customer with a phone number and a positive balance, the
  merchant can open a **reminder preview** containing a pre-written, polite Bangla
  message with the customer's **name** and current **amount** filled in.
- **FR-5.2** The message is **editable** before sending.
- **FR-5.3** The merchant chooses to send via **SMS** or **WhatsApp**; the app
  hands off to the OS (SMS composer / WhatsApp intent) with the message pre-filled.
  The merchant taps send in that app. The app **never auto-sends**.
- **FR-5.4** No SMS gateway, no scheduling, no delivery tracking in v1.
- **FR-5.5** If the customer has **no phone number**, the reminder action prompts
  the merchant to add one first (links to edit customer).
- Full spec: [05-reminders](05-reminders.md).

### FR-6 · Transaction history

- **FR-6.1** The customer-detail screen lists every transaction (credit and
  payment) for that customer, **newest first**, each showing type, amount, date,
  and note if present.
- **FR-6.2** History is **read-only** in v1 — no edit, no delete ([DM-5](04-data-model.md)).
- **FR-6.3** A correction is made by adding a reversing transaction of the
  opposite type (documented to the user via help copy, not a special UI in v1).

### FR-7 · First run & onboarding

- **FR-7.1** No signup wall, no account, no login. The app opens straight to a
  usable state.
- **FR-7.2** On first launch, the empty Home shows one gentle prompt to
  "add your first বাকি" and routes directly into add-customer.
- **FR-7.3** A merchant can go from cold open to their first recorded বাকি in
  **under 3 minutes** with no training and no English ([AC-6](08-acceptance-criteria.md)).
- **FR-7.4** Any phone number for backup/sync is requested **later and optionally**,
  never up front.

### FR-8 · Navigation & app shell

- **FR-8.1** Five screens only (plus first-run): Home, Customer detail, Add
  transaction, Add customer, Reminder preview. See [03-screens](03-screens.md).
- **FR-8.2** Back always returns to the previous screen with no data loss on
  in-progress-but-unsaved entry being discarded intentionally (confirm-on-discard
  only if a value has been entered).
- **FR-8.3** One clear primary action per screen.

---

## 2.3 Out-of-loop behaviors (deferred)

Search, filters, categories, tags, multi-currency, reports, export, undo-history
UI, and reminder scheduling are **not** functional requirements in v1. They are
recorded in [01-scope-and-mvp](01-scope-and-mvp.md) §1.2 as explicitly out.
