# 06 · Non-Functional Requirements

These are as binding as the functional spec. A correct feature that is slow,
online-only, or in English fails the merchant.

## 6.1 Offline

- **NFR-1** The **entire core loop works fully offline**, in airplane mode. Add
  customer, record credit/payment, view balances, and open the reminder composer
  must all function with zero network. This is **non-negotiable** — the merchant
  is assumed to have no signal at time of use.
- **NFR-1.1** No screen in the core loop may block on a network call or show a
  network-dependent spinner.
- **NFR-1.2** SMS/WhatsApp handoff uses the OS and the device radio, not the
  app's data connection — it works with no app-side internet.

## 6.2 Performance (on a low-end phone)

- **NFR-2** Runs without crashing on a **৳5,000–8,000 / low-RAM Android** phone.
- **NFR-2.1** Cold start to usable Home in a couple of seconds on that hardware.
- **NFR-2.2** Recording a transaction (from tapping the action to seeing the
  updated balance) feels **instant** — target < 100 ms perceived on save.
- **NFR-2.3** Home total and list remain smooth with a realistic book: hundreds
  of customers and thousands of transactions. Balances must be computed
  efficiently (indexed queries / cached aggregate — see [04-data-model](04-data-model.md) §4.4).
- **NFR-2.4** Modest install size and memory footprint; assume constrained
  storage.

## 6.3 Usability

- **NFR-3** A non-technical shopkeeper completes the core loop **without
  training**. One clear primary action per screen; large touch targets (~48dp+).
- **NFR-3.1** Add-a-customer-and-record-a-বাকি in **under 15 seconds** for a
  returning user ([AC](08-acceptance-criteria.md)).
- **NFR-3.2** Onboarding to first বাকি in **under 3 minutes** for a first-time
  user, no signup wall.
- **NFR-3.3** Big, glanceable numbers; the money is always the visual focus.

## 6.4 Localization

- **NFR-4** **100% of the core loop is completable without reading any English.**
  All labels, buttons, empty states, and the reminder template are in Bangla.
- **NFR-4.1** Bundle a Bangla font (**Noto Sans Bengali**) — do not depend on the
  device having good Bangla glyphs / conjunct rendering. Verify complex conjuncts
  render correctly on real cheap devices (this is a stated project risk).
- **NFR-4.2** No language switcher in v1 — Bangla only.
- **NFR-4.3** Bangla numerals in display are acceptable; entry may use Western
  digits. Finalize with Phase 0 observation.

## 6.5 Reliability & data safety

- **NFR-5** The merchant's ledger is their livelihood record — **never lose or
  corrupt it.** All writes are durably committed to local SQLite before the UI
  confirms success.
- **NFR-5.1** Append-only transactions ([DM-5](04-data-model.md)) mean no
  in-place mutation can corrupt historical balances.
- **NFR-5.2** The Home total must **always** equal the sum of every customer
  balance — this invariant is testable and must hold after every operation
  ([AC-3](08-acceptance-criteria.md)).
- **NFR-5.3** Cloud backup is deferred, so v1 must at minimum survive app updates
  and restarts without data loss. Consider a simple local export/backup as a
  fast-follow before merchants accumulate months of data.

## 6.6 Privacy & security

- **NFR-6** All data stays **on the device** in v1 (no accounts, no servers, no
  telemetry that ships customer data off-device).
- **NFR-6.1** Customer names and phone numbers are personal data — do not
  transmit them anywhere in v1. The only egress is the reminder message the
  merchant explicitly sends via their own SMS/WhatsApp.
- **NFR-6.2** No third-party analytics SDKs that exfiltrate contact data in v1.
  If crash reporting is added, it must not include customer PII.
- **NFR-6.3** When sync/backup arrives (post-v1), it requires explicit merchant
  consent and must handle PII responsibly.

## 6.7 Regulatory posture

- **NFR-7** v1 **handles no money and moves no funds** — no wallet, no
  bKash/Nagad integration, no payment collection. This keeps the app outside
  financial-services regulation while the market is learned. Do not cross this
  line until the rules and partner APIs are understood (Phase 3+).

## 6.8 Accessibility

- **NFR-8** High contrast, large tap targets, and legible type sizes suitable for
  older merchants and bright-daylight outdoor use. Avoid relying on color alone
  to convey credit vs. payment (pair with the Bangla label and sign).
