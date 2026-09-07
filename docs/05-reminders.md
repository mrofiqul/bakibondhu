# 05 · Reminders — the one real differentiator

This is the feature the khata apps bury and BakiBondhu makes the point. Get the
reminder right and the app has a reason to exist. Get it wrong and it's just
another ledger.

## 5.1 What it is (and isn't) in v1

| In v1 | NOT in v1 |
|-------|-----------|
| **Merchant-triggered** — the merchant taps "মনে করান" | Automatic or scheduled sending |
| Pre-filled polite Bangla message | Bulk / multi-customer send |
| Name + amount injected automatically | An SMS gateway or paid delivery |
| Editable before sending | Delivery / read tracking |
| Handoff to OS SMS **or** WhatsApp | In-app sending (app never sends directly) |

**Why this shape:** using the OS SMS composer / WhatsApp intent means **zero send
cost, zero SMS-gateway integration, and zero spam / regulatory exposure** in v1.
The merchant is always the one who presses send. Paid, bulk, and scheduled
reminders are the **Phase 3** revenue build — a different feature, out of scope
here (see [01-scope-and-mvp](01-scope-and-mvp.md) §1.3).

## 5.2 The message template

Placeholders `[নাম]`, `[পরিমাণ]`, `[দোকানের নাম]` are substituted at preview time.

```
আসসালামু আলাইকুম [নাম] ভাই। আপনার কাছে আমার দোকানে ৳[পরিমাণ] বাকি আছে।
সুবিধামতো একটু পরিশোধ করলে উপকৃত হতাম। ধন্যবাদ — [দোকানের নাম]।
```

- `[নাম]` = `customer.name`
- `[পরিমাণ]` = current positive balance for that customer, formatted with a
  thousands separator (e.g. `45,000`)
- `[দোকানের নাম]` = shop name from first-run settings; if unset, gracefully drop
  the "— [দোকানের নাম]" signature rather than show an empty bracket.
- Tone is deliberately **polite and face-saving** — a neutral reminder solves the
  *emotional* awkwardness of asking, not just the admin task. Do not make it
  demanding.

## 5.3 Flow (FR-5)

```
Customer detail ──tap "মনে করান"──▶ Reminder preview
                                        │
                        ┌───────────────┼───────────────┐
                        ▼               ▼               ▼
                  edit message     SMS পাঠান        WhatsApp
                  (optional)          │               │
                                      ▼               ▼
                              OS SMS composer   WhatsApp intent
                              (pre-filled)      (pre-filled)
                                      │               │
                                      ▼               ▼
                              merchant taps send in that app
```

## 5.4 Rules & edge cases

- **R-1 · No phone number.** If `customer.phone` is empty, the "মনে করান" action
  does not open the composer; it prompts the merchant to add a number (links to
  edit customer). ([FR-5.5](02-functional-spec.md))
- **R-2 · Zero or negative balance.** If the customer owes nothing (balance ≤ 0),
  the reminder action is hidden or disabled — there is nothing to chase. Copy TBD
  in design.
- **R-3 · WhatsApp not installed.** If the WhatsApp intent cannot resolve, fall
  back gracefully (hide the button, or show a short "WhatsApp পাওয়া যায়নি"
  message) and keep SMS available.
- **R-4 · Editing.** The merchant may edit the message freely before sending; the
  app does not re-inject or validate after edit.
- **R-5 · No logging in v1.** The app does not record that a reminder was sent
  (no send history, no "last reminded" timestamp). This is a candidate for a
  fast-follow once retention is proven, but is out of scope for v1 to keep the
  data model at two tables.
- **R-6 · Amount at send time.** The injected amount is the balance **at the
  moment of preview.** If the balance changes later, the already-sent message is
  not updated (it's just a text message).

## 5.5 Localization notes

- Message ships in Bangla only. Merchant edits are free-form.
- Use the customer's stored name verbatim; do not transliterate.
- Currency symbol `৳` precedes the amount.

## 5.6 Why the reminder is the wedge (design intent)

TallyKhata and HishabPati both let a merchant *record* dues; neither makes
*collecting* the headline job. The one-tap polite Bangla nudge is the smallest
feature that reframes the whole product from "a place to write বাকি down" to "the
app that gets বাকি paid back." Every design decision on this screen should protect
that framing: fast, polite, merchant-in-control.
