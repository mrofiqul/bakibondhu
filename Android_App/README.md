# BakiBondhu — Android App

The offline-first, Bangla-first **field application** (Flutter + Dart). This is the primary
app for merchants and field staff; it must work reliably with weak/no internet (app-spec §29).

## Governing specifications

| Concern | Document |
|---|---|
| Screens, fields, states, navigation | `../documents/BakiBondhu_Android_UIUX_Specification` |
| Product/functional requirements | `../documents/BakiBondhu_Android_Web_Application_Specification_v1.1` |
| API contract | `../documents/BakiBondhu_REST_API_Specification` |
| Offline sync engine & payment allocation | `../documents/BakiBondhu_Offline_Sync_Technical_Design` |
| Local data mirror | `../documents/BakiBondhu_Database_Specification` (SQLite mirrors the synced entities) |
| Structure, style, testing | `../documents/BakiBondhu_Development_Coding_Standards` |

## Folder structure (Coding Standards §2.2 — feature-first)

```
lib/
  core/         cross-cutting: theme, localization (Bangla-first), config, errors
  data/         repositories, SQLite (drift/sqflite), API clients, DTOs
  domain/       entities + pure business logic (balance, aging) — unit-tested, no framework deps
  sync/         offline sync engine: outbox, push/pull, conflict review (see Offline Sync spec)
  features/
    auth/         login + phone/OTP, app-lock (§38)
    dashboard/    home tiles + collection priorities (§8.2)
    customers/    list, add/edit, detail (§8.3–8.5)
    transactions/ record credit / payment, history (§8.6–8.7)
    collections/  collection activities + promise-to-pay (§8.8–8.9)
    reminders/    reminder preview → SMS/WhatsApp (§9, §34)
    settings/     language, quiet hours, business switch, export (§35–36)
test/           widget + integration tests (run on a real low-end device)
```

## Getting started

1. `flutter create .` in this folder to generate the platform projects (`android/`, `ios/`),
   `pubspec.yaml`, and entry point, keeping the `lib/` structure above.
2. Add: drift/sqflite (offline SQLite), a state solution, an HTTP client, and Noto Sans Bengali
   (bundled — verify conjuncts on a real ৳5–8k device, §33).
3. Build the **core loop first** (add customer → credit → payment → balance → reminder),
   fully offline, then wire sync.

**Non-negotiables:** the whole core loop works in airplane mode; balances are computed
(`Σ amount × balance_sign`), never stored; financial rows are append-only; 100% of the core
loop is completable in Bangla.
