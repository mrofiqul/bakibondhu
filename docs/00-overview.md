# 00 · Product Overview

## 0.1 One-line definition

BakiBondhu is a **collection-first ledger** for micro-merchants: the app that
gets a shopkeeper's **বাকি** (credit owed to them) paid back, not just recorded.

## 0.2 The problem

Around 8 million Bangladeshi micro-businesses sell on credit (বাকি). They track
it in a paper notebook or from memory, forget who owes what, feel awkward
chasing it, and quietly lose money every month.

**Recording is not the pain. Getting paid back is.** Existing khata apps
(TallyKhata, HishabPati) treat the ledger as the product and collection as a
buried side-feature. BakiBondhu inverts that: collection is the main event.

## 0.3 What v1 does (the one job)

A shopkeeper can:

1. Record **who owes them** money,
2. Log **payments** as they come in,
3. Always see the **true total owed** to them, and
4. **Nudge** a customer to pay —

all in Bangla, all with no internet connection. Nothing else ships in v1.

## 0.4 Product goals & success signals

The MVP exists to answer one question: **will a merchant use this daily,
unprompted, and does their stuck money go down?** Growth is not a v1 goal.

| Goal | Success signal (Phase 2) |
|------|--------------------------|
| Daily habit | Merchant opens the app and records a real transaction the day *after* onboarding, without being reminded |
| Trust in the numbers | Home-screen total always matches reality; merchant stops cross-checking the paper khata |
| Less stuck money | Merchant's overdue বাকি drops over weeks of use |
| Frictionless onboarding | A non-technical shopkeeper is recording their first বাকি in under 3 minutes, with zero training |

Explicit **non-goals** for v1: revenue, user growth, multi-user, analytics
dashboards, and anything touching money movement.

## 0.5 Target user (persona)

**Rahim, wholesaler / kirana shopkeeper.** Mid-30s to 50s. Runs a busy shop or
distribution counter. Sells to 15–40 regular customers on credit. Cheap Android
phone (৳5,000–8,000, low RAM), intermittent data, reads Bangla, limited or no
English. Keeps বাকি in a worn paper notebook and his head. Loses real money to
forgotten and unchased dues, and dreads the awkward "where's my money"
conversation.

Design tension he embodies: **big fingers, small screen, no patience, no
signal, no English.** Every screen is built for him.

## 0.6 Design principles

1. **Collection is the hero.** Every screen bends toward "get paid back."
2. **Bangla-first, always.** The entire core loop is completable without reading
   one word of English.
3. **Offline is not a feature, it's the baseline.** The app is fully usable in
   airplane mode.
4. **Remove, don't add.** Where incumbents add features, we cut them. If a
   behavior can't be explained in one sentence, it doesn't ship.
5. **Never store what you can compute.** Balances are always derived from an
   append-only transaction log — the numbers can never silently drift.
6. **Instant feel.** Every core action must feel immediate on a low-end phone.

## 0.7 Glossary

| Term | Meaning |
|------|---------|
| **বাকি** (baki) | Credit — goods sold now, paid for later. The money a customer owes the merchant. |
| **Party / কাস্টমার** | A customer the merchant extends credit to. The two words are used interchangeably; UI uses কাস্টমার. |
| **বাকি দিলাম** | "I gave credit" — a *credit* transaction (increases what the customer owes). |
| **টাকা পেলাম** | "I received money" — a *payment* transaction (decreases what the customer owes). |
| **Balance** | For one customer: Σ credits − Σ payments. Positive = they owe the merchant. |
| **Total owed / মোট বাকি** | Sum of all positive customer balances — the headline number on Home. |
| **Reminder / মনে করান** | A merchant-triggered, pre-filled polite Bangla message asking a customer to pay. |
| **Aging** | How long a balance has been outstanding (e.g. "১২ দিন পার" — 12 days past). |
| **MFS** | Mobile Financial Service (bKash, Nagad, Rocket). **Not** handled in v1. |
