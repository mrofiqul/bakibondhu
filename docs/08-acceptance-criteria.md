# 08 · Acceptance Criteria & Definition of Done

## 8.1 The only metric that matters in Phase 1

> Does a merchant open the app and record a real transaction **the next day —
> without you reminding them?** If yes, you have something. If no, no feature
> will save it; fix the core loop before building anything else.

Everything below is the functional floor that makes that test possible.

## 8.2 Release acceptance criteria

v1 is "done" only when **all** of these are true:

- **AC-1** A merchant can add a customer and record a বাকি in **under 15
  seconds**. → [NFR-3.1](06-non-functional.md), [FR-1](02-functional-spec.md), FR-2
- **AC-2** The app works **fully in airplane mode** — the entire core loop, no
  network. → NFR-1
- **AC-3** The Home-screen total **always equals** the sum of every customer
  balance, after any sequence of operations. → FR-4.2, NFR-5.2, DM-4
- **AC-4** The reminder opens with the **correct name and amount** pre-filled, and
  hands off cleanly to SMS or WhatsApp. → FR-5, [05-reminders](05-reminders.md)
- **AC-5** The **entire core loop is completable without reading any English.** →
  NFR-4
- **AC-6** A first-time merchant reaches their first recorded বাকি in **under 3
  minutes**, with no signup and no training. → FR-7
- **AC-7** It **runs without crashing** on a ৳5,000–8,000 / low-RAM Android phone,
  including correct Bangla conjunct rendering. → NFR-2, NFR-4.1
- **AC-8** No transaction can be silently lost: every saved entry survives app
  restart and update. → NFR-5

## 8.3 Correctness checklist (money math)

These are unit-testable against the pure domain logic and must all pass:

- [ ] `credit` increases a customer's balance by exactly the amount.
- [ ] `payment` decreases a customer's balance by exactly the amount.
- [ ] Customer balance = Σ credits − Σ payments, always. (DM-3)
- [ ] Overpayment yields a correct **negative** balance; app does not block it. (FR-3.3)
- [ ] `total_owed` = sum of **positive** balances only; negatives are not netted in. (DM-4)
- [ ] Amount is stored positive; direction comes from `type`, never a stored sign. (DM-1)
- [ ] Home list is sorted biggest / oldest first. (FR-4.4)
- [ ] Aging is derived correctly from transaction dates. (DM-7)
- [ ] A reversing transaction correctly undoes a mistaken entry (no edit/delete). (DM-5)

## 8.4 Flow / UX checklist

- [ ] First run: no signup wall; empty Home routes to add-customer. (FR-7)
- [ ] Add customer requires only a non-empty name; phone optional. (FR-1)
- [ ] Add transaction defaults date to today; amount required and > 0. (FR-2)
- [ ] Customer detail shows balance on top and full history newest-first. (FR-6)
- [ ] Reminder blocked/redirected when the customer has no phone. (R-1 / FR-5.5)
- [ ] Reminder hidden/disabled when balance ≤ 0. (R-2)
- [ ] WhatsApp-missing fallback keeps SMS available. (R-3)
- [ ] Back navigation never loses saved data; unsaved-entry discard confirms. (FR-8.2)

## 8.5 Non-functional checklist

- [ ] Full core loop verified offline. (NFR-1)
- [ ] Save feels instant (<100 ms perceived) on low-end hardware. (NFR-2.2)
- [ ] Smooth with hundreds of customers / thousands of transactions. (NFR-2.3)
- [ ] Bundled Noto Sans Bengali renders all UI conjuncts correctly on a real cheap device. (NFR-4.1)
- [ ] No customer PII leaves the device except a merchant-sent reminder. (NFR-6)
- [ ] No money movement / MFS integration anywhere. (NFR-7)

## 8.6 Out-of-scope guard (must be ABSENT from v1)

Confirm these did **not** sneak in:

- [ ] No in-app payments / wallet, no bKash-Nagad.
- [ ] No inventory / products / barcodes.
- [ ] No accounting / VAT / profit reports.
- [ ] No automatic or scheduled reminders; no SMS gateway.
- [ ] No staff logins / multi-user; no web dashboard.
- [ ] No language beyond Bangla.
- [ ] No editing or deleting of past transactions.
- [ ] No cloud sync forced on the user.
