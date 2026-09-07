# 07 · Architecture & Tech Stack

All choices are **free-tier** and chosen for one constraint above all: **scope
discipline on a solo build.** You already have the tech skills; the enemy is
scope, not tooling.

## 7.1 Recommended stack

| Layer | Choice | Why |
|-------|--------|-----|
| App framework | **Flutter** (React Native is a fine alternative if you know it better) | One codebase, smooth on cheap Android |
| Local storage | **SQLite** via `drift` or `sqflite` | Offline-first, relational, fast on-device |
| Bangla type | **Noto Sans Bengali** (bundled) | Reliable conjunct rendering, not device-dependent |
| Reminders | OS **SMS composer** + **WhatsApp intent** | No gateway, no cost, no regulation in v1 |
| Sync / backup (later) | **Supabase** or **Firebase** free tier | Add only once merchants rely on the app |

v1 **may ship local-only** with no backend at all. That is an acceptable and
even preferred starting point.

## 7.2 Architecture shape

```
┌──────────────────────────────────────────────┐
│                     UI                          │
│  5 screens (Bangla-first) + first-run          │
│  Home · Detail · Add-txn · Add-customer · Remind│
└───────────────────────┬────────────────────────┘
                        │ intents
        ┌───────────────┼────────────────────────┐
        ▼                                          ▼
┌────────────────┐                      ┌────────────────────┐
│  Domain / logic │                      │   OS integrations   │
│  balances,      │                      │  SMS composer,      │
│  aging, totals  │                      │  WhatsApp intent    │
│  (pure, tested) │                      └────────────────────┘
└───────┬─────────┘
        ▼
┌────────────────┐
│  Local store    │   SQLite (drift/sqflite)
│  customer,      │   append-only transactions
│  transaction    │   UUID keys, computed balances
└────────────────┘
        ▼ (post-v1, optional)
┌────────────────┐
│  Cloud sync     │   Supabase/Firebase — NOT in v1
└────────────────┘
```

## 7.3 Key technical decisions

- **Local-first, single source of truth = the transaction log.** Balances are
  computed, never stored ([04-data-model](04-data-model.md)). This removes a
  whole class of drift/consistency bugs.
- **Domain logic is pure and unit-tested** — balance, total-owed, and aging
  calculations should be plain functions with no UI or DB dependency, so the
  money math can be tested exhaustively ([AC-3](08-acceptance-criteria.md)).
- **UUID primary keys from day one** so a future sync can merge devices without
  key collisions, even though sync isn't built yet.
- **OS handoff for messaging** keeps the app free of an SMS gateway, delivery
  infrastructure, and the associated cost/regulation until Phase 3.
- **No backend in v1.** No auth, no API, no server to run or pay for. This is what
  keeps the business's cash-at-risk near zero during the build months.

## 7.4 What this stack deliberately avoids in v1

- No payment SDKs / MFS integration (regulatory line — [NFR-7](06-non-functional.md)).
- No analytics SDK that ships customer PII off-device ([NFR-6](06-non-functional.md)).
- No SMS gateway (that's the Phase 3 paid-reminder build).
- No web app, no admin panel, no multi-user backend.

## 7.5 Build & release

- Target: modern Android, but **test on genuinely cheap, low-RAM hardware**, not
  just an emulator or a flagship phone ([09-roadmap](09-roadmap.md), Week 7).
- Distribute the pilot build hand-to-hand (APK / limited track) to the 3 friendly
  merchants from Phase 0 before any public listing.
