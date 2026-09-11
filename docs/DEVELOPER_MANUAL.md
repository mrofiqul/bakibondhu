# BakiBondhu — Developer Manual

A complete guide for developers working on **BakiBondhu**, a Bangla-first,
offline-first credit-ledger app for Bangladeshi micro-merchants.

- **Android app:** Flutter/Dart (the primary product; works fully offline)
- **Auth backend (in production):** vanilla PHP + MySQL, hosted on InfinityFree
- **Sync backend (prepared, not yet deployed):** ASP.NET Core 9 + PostgreSQL

---

## 1. Repository layout

```
BakiBondhu/
├── Android_App/            Flutter app (the product)
│   ├── lib/
│   │   ├── main.dart       Composition root (wires storage, auth, sync)
│   │   ├── app.dart        Root widget + entry routing (landing vs home)
│   │   ├── core/           Theme, Bangla strings, formatting, AppScope, dialogs
│   │   ├── domain/         Pure business rules (money, balance, allocation, aging)
│   │   ├── data/           Repositories (sqflite), auth API, session, InfinityFree client
│   │   ├── sync/           Sync engine, types, HTTP sync API, local sync store
│   │   └── features/       UI by feature (onboarding, dashboard, customers,
│   │                       transactions, collections, reminders, auth, sync, settings)
│   ├── test/               Unit + widget tests (pure-Dart domain + widgets)
│   └── android/            Android project (gradle.properties has the Windows build fix)
├── php_backend/            PHP + MySQL auth backend (deployed to InfinityFree)
│   ├── index.php           Front controller / router (/health, /api/v1/auth/*)
│   ├── lib.php             DB (PDO), JSON helpers, UUID, HS256 JWT
│   ├── config.php          SECRETS (DB creds + jwt_secret) — GITIGNORED
│   ├── config.sample.php   Template committed to git
│   ├── setup.php           One-time table creator (delete after use)
│   ├── schema.sql          MySQL schema (businesses, users)
│   ├── index.html          Public landing page (served at site root)
│   └── .htaccess           DirectoryIndex + routing + apk MIME
├── Backend/                ASP.NET Core 9 + PostgreSQL (prepared for real sync)
│   ├── BakiBondhu.Api/     Minimal-API endpoints, JWT, DI, PORT binding
│   ├── BakiBondhu.Application / .Domain / .Infrastructure / .Tests
│   ├── Dockerfile          Container image (binds to $PORT)
│   ├── render.yaml*        (repo root) Render blueprint
│   ├── scripts/            dev_db_setup.sql, cloud_db_setup.sql
│   └── DEPLOY.md, DEPLOY_RENDER.md
├── documents/              Formal specs (app, DB, REST, sync, QA, DevOps)
├── docs/                   This manual + the end-user manual
└── Installer/              Built APKs / zips — GITIGNORED (not in repo)
```

---

## 2. Architecture at a glance

- **Offline-first.** All data lives in on-device SQLite (`sqflite`). The app is
  fully usable with no network. An account + backend enable (future) multi-device
  sync; today the hosted backend covers **auth only**.
- **Domain is pure Dart.** `lib/domain/` holds the money/balance/allocation/aging
  rules with no Flutter or DB dependencies, and is unit-tested in isolation. The
  same rules are mirrored server-side (PL/pgSQL in the .NET path).
- **Money is integer paisa** everywhere (never floating point). `Money` wraps an
  `int` of paisa; ৳1 = 100 paisa.
- **Append-only ledger.** Transactions are never edited/deleted; balance =
  Σ(amount × sign). Payments are allocated to credits FIFO.
- **Composition root** is `main.dart`: it opens the DB, builds the repository,
  settings, session, auth API and sync engine, and injects them via `AppScope`
  (an `InheritedWidget`). Screens never construct their own storage.

### Tech stack
| Layer | Choice |
|---|---|
| App | Flutter (Dart ≥ 3.3), Material 3 |
| Local storage | `sqflite`, `shared_preferences`, `flutter_secure_storage` |
| Networking | `http` + custom `InfinityFreeClient` (AES via `pointycastle`) |
| Auth backend | PHP 8 (PDO/MySQL), HS256 JWT, bcrypt |
| Sync backend (prepared) | ASP.NET Core 9, Npgsql/Dapper, PostgreSQL, RLS |

---

## 3. Local development (the app)

### Prerequisites
- Flutter SDK (this repo built under Flutter 3.4x; Dart ≥ 3.3).
- Android SDK + an emulator or a device. On Windows, `winget install` for the
  Android command-line tools + a hypervisor (AEHD) for the x86_64 emulator.

### Run
```bash
cd Android_App
flutter pub get
flutter run -d <device>          # picks up the default backend URL
```
The backend base URL is a compile-time constant with a dart-define override:
```bash
# default is http://10.0.2.2:5080 (emulator -> host loopback, for local .NET dev)
flutter run --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
```

### Test
```bash
flutter test          # domain + widget + InfinityFree-client tests (29 total)
flutter analyze       # must be clean
```

### Build a release APK
```bash
flutter build apk --release --split-per-abi \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
# outputs: build/app/outputs/flutter-apk/app-{arm64-v8a,armeabi-v7a,x86_64}-release.apk
```
`app-arm64-v8a-release.apk` is the one for modern phones.

---

## 4. App entry flow

`main.dart` decides the first screen:
```
startLanding = !onboardingComplete && session.token == null
```
- **Landing** (`features/onboarding/landing_screen.dart`) — Login / Register /
  “Continue offline”. Shown until the user signs in or finishes offline setup.
- **Register** → saves the business name as the shop name, marks onboarding
  complete, goes Home.
- **Login** → marks onboarding complete, goes Home.
- **Continue offline** → shop-name onboarding → Home.
- **Logout** (Sync Center) → clears the session, resets the onboarding flag, and
  navigates back to the landing screen (back stack cleared).

Screens of note: `dashboard/home_screen.dart` (total + customer list),
`customers/customer_detail_screen.dart` (balance, history, actions),
`transactions/add_transaction_screen.dart` (numeric pad),
`collections/collection_screen.dart`, `reminders/reminder_preview_screen.dart`,
`sync/sync_center_screen.dart`, `settings/settings_screen.dart`.

> **State pattern:** screens hold the loaded data in state and call an async
> `_refresh()` that `setState`s the concrete data. Do **not** reintroduce the
> `setState(() => _future = _load())` + `FutureBuilder` pattern — it left stale
> data on screen (fixed in commit *live-refresh*).

---

## 5. The auth backend (PHP + MySQL on InfinityFree)

**Live at:** `https://bakibondhu.infinityfreeapp.com`
**Endpoints:**
- `GET /health` → `{"status":"ok",...}`
- `POST /api/v1/auth/register` — body `{name, phone, password, business_name}` → 201
- `POST /api/v1/auth/login` — body `{identifier, password}` → 200

Response shape the app parses: `tokens.access_token` (+ optional
`access_expires_in`, `role`, `business.id`/`business_id`); errors as
`{"error":{"code","message"}}`.

### Deploy / update
1. Edit `php_backend/config.php` (DB host/name/user/pass + `jwt_secret`).
2. Upload files into the host's `htdocs` via FTP:
   ```bash
   curl --user "<ftp_user>:<ftp_pass>" -T index.php   ftp://ftpupload.net/htdocs/index.php
   # …repeat for lib.php, config.php, .htaccess, index.html
   ```
3. Create tables once by hitting `setup.php` (needed because InfinityFree blocks
   **remote** MySQL): `https://<site>/setup.php?key=<jwt_secret>` — **then delete it**.
4. `.htaccess` sets `DirectoryIndex index.html index.php`, so `/` serves the
   landing page while `/health` and `/api/*` route to `index.php`.

### ⚠️ InfinityFree constraints (important)
- **Anti-bot "browser check".** Every request first gets a JavaScript
  `aes.js`/`__test`-cookie challenge. A browser solves it; a plain HTTP client
  cannot. The app handles this with **`data/infinityfree_client.dart`** — it
  detects the challenge, AES-128-CBC-decrypts the embedded block to the cookie,
  and **replays the request on a fresh connection** (reusing the challenge's
  keep-alive connection makes the proxy return `400 Bad Request`). Unit-tested in
  `test/data/infinityfree_client_test.dart`.
- **No remote MySQL** — hence `setup.php`. To inspect/reset data, use phpMyAdmin
  in the InfinityFree panel.
- **No file hosting** — InfinityFree auto-deletes uploaded APKs. Distribute the
  app via GitHub releases (see §7), not from `htdocs`.
- **Against their ToS** to use free hosting as an app backend — the account can be
  suspended. Treat this as a testing/personal setup, not a production foundation.

### Credentials (do not commit)
Live in `php_backend/config.php` (gitignored). Current dev values are also in the
project memory. Rotate `jwt_secret` and the DB password for any real use.

---

## 6. The sync backend (.NET + PostgreSQL) — prepared, not deployed

`Backend/` is a Clean-Architecture ASP.NET Core 9 API with JWT auth and
PostgreSQL row-level-security tenant isolation. It is production-shaped and
**ready to deploy** when real multi-device sync is needed; the PHP backend can’t
run it (shared hosting).

- Config via env: `ConnectionStrings__App`, `Jwt__Key`, `Jwt__Issuer`, `PORT`.
- `Dockerfile` builds it and binds to `$PORT`. `render.yaml` is a Render blueprint.
- `scripts/cloud_db_setup.sql` creates the non-owner `bakibondhu_app` role RLS
  requires. Apply `documents/BakiBondhu_PostgreSQL_Schema.sql` first (as owner).
- Full guide: **`Backend/DEPLOY_RENDER.md`** (Render + Neon, both free tiers).
- To point the app at it: rebuild with
  `--dart-define=SYNC_BASE_URL=https://<render-domain>` (HTTPS; the InfinityFree
  client is inert on a normal host).

---

## 7. Release & distribution

- **Code repo (private):** `github.com/mrofiqul/bakibondhu` — `main` is the
  release branch. `gh auth setup-git` is configured so `git push` uses the gh
  token (no credential-manager popups).
- **App downloads (public):** `github.com/mrofiqul/bakibondhu-app` — the APK is
  published as a GitHub **release**; the landing page links to the stable URL
  `…/releases/latest/download/BakiBondhu.apk`.

### Publish a new app version
```bash
flutter build apk --release --split-per-abi \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
gh release create vX.Y.Z \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  --repo mrofiqul/bakibondhu-app --title "BakiBondhu vX.Y.Z" --notes "…"
```
The landing button auto-serves the newest release — no page change needed.

---

## 8. Data model (essentials)

**Local (SQLite):** `customers(id, name, phone, …)`,
`transactions(id, customer_id, type, amount_paisa, due_date, created_at, …)`
append-only, plus `collection_activities`, `promise_to_pay`, `sync_meta`.
Balances/aging are computed in Dart from the ledger.

**Auth backend (MySQL):** `businesses(id, name, timezone, currency, created_at)`,
`users(id, business_id, name, phone UNIQUE, password_hash, role, created_at)`.
Passwords are bcrypt; tokens are HS256 JWT (`sub`, `business_id`, `role`, `exp`).

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| App shows “অ্যাপটি খোলা গেল না” on login/register | Network or the InfinityFree challenge not solved. Confirm the site is up (`/health`), and that the build points at the right `SYNC_BASE_URL`. |
| `400 Bad Request` (openresty) on the cookied retry | Keep-alive reuse — each request must use a fresh connection (already handled in `InfinityFreeClient`). |
| Login returns HTML / `FormatException` | The browser-check page reached the app un-solved; check `InfinityFreeClient` detection (page < 4 KB, contains `toNumbers(`/`slowAES`). |
| APK 404 on the site | InfinityFree deleted it — use the GitHub release URL. |
| Windows build: “Could not close incremental caches” | `kotlin.incremental=false` in `android/gradle.properties` (already set). |
| Emulator won’t boot / black screen | Kill stale `qemu`/`emulator`, clear `*.lock`, cold-boot with `-gpu swiftshader_indirect`; a corrupt data partition needs `-wipe-data`. |

---

## 10. Roadmap
- Deploy the .NET + Postgres backend (Render + Neon) and enable real multi-device
  **sync** (push/pull already implemented app-side).
- Refresh/rotate secrets; add refresh tokens.
- Web app (Flutter web) — the same domain rules apply.
