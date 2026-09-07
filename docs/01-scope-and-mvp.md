# 01 · Scope & the MVP Fence

This is a **fence, not a wishlist.** One core loop, five screens, offline, in
Bangla. Everything below the fence is a reasonable idea and also how solo MVPs
die. Say no until users force your hand.

## 1.1 In scope (v1 — the whole loop)

| # | Capability | Ref |
|---|------------|-----|
| 1 | Add a customer (party) | [FR-1](02-functional-spec.md) |
| 2 | Record a sale on credit — বাকি দিলাম | FR-2 |
| 3 | Record a payment received — টাকা পেলাম | FR-3 |
| 4 | See running balance per party **and** total owed | FR-4 |
| 5 | One-tap SMS / WhatsApp reminder in Bangla | FR-5 |
| 6 | Works fully offline; local-first storage | [NFR-1](06-non-functional.md) |
| 7 | Bangla-first UI across the entire loop | NFR-4 |
| 8 | Onboarding to first बাकি in under 3 minutes | FR-7 |

## 1.2 Explicitly OUT of v1 (the "not now" fence)

Each of these is deferred **on purpose.** Do not build them until real users
repeatedly demand them.

| Out of scope in v1 | Why deferred |
|--------------------|--------------|
| In-app payments / bKash–Nagad wallet | Money movement invites financial regulation and partner-API complexity. Stay clear until the rules are understood (Phase 3+). |
| Inventory, products, barcodes | Not the collection job. Scope bloat. |
| Accounting, VAT, profit reports | That is HishabPati's game; competing there loses. |
| **Automatic / scheduled reminders** | v1 reminders are merchant-*triggered* only — no SMS gateway, no scheduler, no send cost, no spam risk. See [05-reminders](05-reminders.md). |
| Staff logins / multi-user | Single device, single merchant in v1. |
| Web dashboard | Merchant lives on the phone. |
| Any language beyond Bangla | Bangla-first is the wedge. Localization is a later-market concern. |
| Editing / deleting past transactions | The ledger is append-only. Corrections are made by adding a reversing entry ([DM-5](04-data-model.md)). |
| Cloud sync / backup | v1 may ship **local-only.** Add cloud backup once merchants rely on the app, not before. |

## 1.3 Monetization is NOT in v1

The core is free forever. The eventual revenue lines — **paid bulk reminders**
(pass-through SMS + margin), multi-shop, party-wise pro reports — require an SMS
gateway and are a **Phase 3** build, not part of this spec. v1's job is to prove
daily use and retention; it earns nothing and costs almost nothing to run.

> **Note for planning:** because the paid reminder feature is a different build
> from v1's free merchant-triggered reminder, Phase 0 interviews must probe
> *willingness to pay for reminders* directly — that assumption is load-bearing
> for the whole business and is not validated by shipping v1.

## 1.4 Assumptions

- Phase 0 interviews confirm collection (not recording) is a top-3 pain **before**
  this is built. If not, the vertical or the feature pivots first.
- The lead vertical is **wholesalers / distributors** (bigger credit cycles, more
  money at stake, more willing to pay) — to be confirmed in Phase 0.
- Merchants have a Bangla-capable Android phone and can send SMS / use WhatsApp.
- Customers' phone numbers are available often enough for reminders to matter
  (numbers are optional in the data model but pushed in the UI).

## 1.5 Constraints

| Constraint | Value |
|------------|-------|
| Team | Solo founder (technical), part-time freelance-funded |
| Budget | ৳0 / free tiers only |
| Timeline | Feature-complete v1 by ~Week 10 (see [09-roadmap](09-roadmap.md)) |
| Target device | Cheap Android, ৳5,000–8,000, low RAM, small screen |
| Connectivity | Must assume no signal at time of use |
| Language | Bangla for 100% of the core loop |
| Regulation | No handling of funds → stays outside financial regulation in v1 |
