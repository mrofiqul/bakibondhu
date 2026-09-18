# BakiBondhu — Developer Manual

A complete guide for developers working on **BakiBondhu**, a Bangla-first,
offline-first credit-ledger app for Bangladeshi micro-merchants.

- **Android app:** Flutter/Dart (the primary product; works fully offline)
- **Backend (in production):** vanilla PHP + MySQL on InfinityFree — auth, cloud
  **sync**, and a super-**admin** panel
- **Alternative sync backend (prepared, not deployed):** ASP.NET Core 9 +
  PostgreSQL — for when usage outgrows shared hosting

---

## 1. Repository layout

```
BakiBondhu/
├── Android_App/            Flutter app (the product)
│   ├── lib/
│   │   ├── main.dart       Composition root (wires storage, auth, sync)
│   │   ├── app.dart        Root widget + entry routing (landing vs home)
│   │   ├── core/           Theme, bilingual strings (`strings_bn.dart` = runtime
│   │   │                   বাংলা/English `S`), `language.dart`/`language_toggle.dart`,
│   │   │                   `config.dart` (base URL + version), `xlsx_writer.dart`,
│   │   │                   `update_service.dart`, formatting, validators, bd_geo, AppScope
│   │   ├── domain/         Pure business rules (money, balance, allocation, aging)
│   │   ├── data/           Repositories (sqflite), auth API, session, InfinityFree client
│   │   ├── sync/           Sync engine, types, HTTP sync API, local sync store
│   │   └── features/       UI by feature (onboarding, dashboard, customers,
│   │                       transactions, collections, reminders, auth, sync, settings)
│   ├── test/               Unit + widget tests (pure-Dart domain + widgets)
│   └── android/            Android project (gradle.properties has the Windows build fix)
├── php_backend/            PHP + MySQL backend (deployed to InfinityFree)
│   ├── index.php           Front controller / router (auth, sync, admin)
│   ├── lib.php             DB (PDO), JSON, UUID, HS256 JWT sign+verify, auth guards
│   ├── admin_lib.php       Admin auth (scoped JWT), reports, actions, audit log,
│   │                       customer .xlsx export (grouped by shop)
│   ├── xlsx.php            Dependency-free .xlsx writer (zipped XML: crc32 + deflate)
│   ├── app_version.php     Latest app/web build for the in-app update check
│   ├── admin/index.html    Super-admin dashboard SPA (served at /admin)
│   ├── app/index.html      Shopkeeper web app SPA — bilingual (served at /app)
│   ├── admin_setup.php     One-time first-admin bootstrap (delete after use)
│   ├── setup.php           One-time table creator (delete after use)
│   ├── config.php          SECRETS (DB creds + jwt_secret) — GITIGNORED
│   ├── config.sample.php   Template committed to git
│   ├── schema.sql          MySQL schema (businesses, users, customers,
│   │                       transactions, admins, admin_audit)
│   ├── index.html          Public landing page (served at site root)
│   └── .htaccess           DirectoryIndex + routing + Authorization + apk MIME
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
  fully usable with no network. Signing in enables **cloud sync** (push/pull to the
  PHP backend) so the ledger survives a lost or replaced phone; the same backend
  also serves the platform **admin** panel.
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
| Local storage | `sqflite`, `shared_preferences`, `flutter_secure_storage`, `path_provider` |
| Networking | `http` + custom `InfinityFreeClient` (AES via `pointycastle`) |
| Auth backend | PHP 8 (PDO/MySQL), HS256 JWT, bcrypt |
| Sync backend (prepared) | ASP.NET Core 9, Npgsql/Dapper, PostgreSQL, RLS |

### Recent features (v0.1.17 – v0.1.21)
- **v0.1.17 — unified collections/promises into sync.** `EntityKind` gained
  `collection`/`promise`; sync push/pull handles them so app and web share them on
  the one DB (`collection_activities`, `promise_to_pay`).
- **v0.1.18 — Excel (.xlsx) customer-report export** on app + web + admin. `.xlsx`
  is hand-built everywhere (no PhpSpreadsheet, no `archive` pkg): zipped XML via
  CRC-32 + raw DEFLATE. Server: `php_backend/xlsx.php` + `GET /api/v1/admin/export/
  customers.xlsx` (all customers grouped by shop). Android:
  `lib/core/xlsx_writer.dart` (shared to the OS via `share_plus`, staged with
  `path_provider`). Web: lazy-loads SheetJS from cdnjs on demand.
- **v0.1.19 — in-app update.** Public `GET /api/v1/app/version` (from
  `app_version.php`) advertises the latest build. Android `lib/core/update_service.dart`
  compares `kAppBuild` and opens the APK URL; web compares `WEB_BUILD` and reloads.
  Installing over the same signed package keeps all data.
- **v0.1.20 — registered owners only.** Removed the "continue without account"
  path and the offline onboarding screen; login/register is required
  (`startLanding = !onboarded && token == null`; login/register set
  `onboardingComplete`). Existing data is untouched.
- **v0.1.21 — বাংলা / English language selection.** Android: `strings_bn.dart` is
  now a runtime bilingual `S` (`AppLang` enum + getters); an `appLanguage`
  `ValueNotifier` rebuilds the root (`app.dart`), the choice persists via
  `SettingsStore.language()`, and a `LanguageToggle` sits at the top of the landing
  screen + in Settings (so nearly all `const Text(S.x)` became non-const). Web: the
  Bangla source is the base and, when English is selected, a curated `bn→en` map +
  a post-render DOM translator (`translateDom`) rewrite the text nodes; toggle on the
  auth screen + Settings, persisted in `localStorage`.
- **v0.1.22 — Download the customer report** (was "Export"). Android now writes the
  `.xlsx` straight to the public **Downloads** folder via a small MediaStore
  platform channel (`bakibondhu/downloads` in `MainActivity.kt`, API 29+), with a
  fallback/`Save to…` picker through `file_saver`'s `saveAs` (note: file_saver's
  `saveFile` writes to app-private storage, so it isn't used for the default). Web
  and admin already trigger real browser downloads; all three were relabelled
  Export → **Download**.

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
The backend base URL is a compile-time constant (`kSyncBaseUrl` in
`lib/core/config.dart`) with a dart-define override; the admin-panel URL
(`kAdminPanelUrl`) is derived from it:
```bash
# default is http://10.0.2.2:5080 (emulator -> host loopback, for local .NET dev)
flutter run --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
```

### Test
```bash
flutter test          # domain + widget + InfinityFree-client + sync-contract tests
flutter analyze       # must be clean
```

### Build a release APK
```bash
flutter build apk --release --target-platform android-arm64,android-arm \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
# outputs: build/app/outputs/flutter-apk/app-release.apk (~34 MB)
```
`--target-platform android-arm64,android-arm` drops the emulator-only **x86_64**
native libraries, so the single APK is ~34 MB (not ~54 MB) and still runs on every
real phone (arm64-v8a + armeabi-v7a). This release APK will **not** run on an
x86_64 emulator — for emulator testing use a plain `flutter build apk --debug` (all
ABIs) or `flutter run`.

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

## 5. The backend (PHP + MySQL on InfinityFree)

One PHP backend serves three concerns — **auth**, **cloud sync**, and the
**admin** panel. **Live at:** `https://bakibondhu.infinityfreeapp.com`.

### Auth endpoints
- `GET /health` → `{"status":"ok",...}`
- `POST /api/v1/auth/register` — body `{name, phone, password, business_name}` → 201
- `POST /api/v1/auth/login` — body `{identifier, password}` → 200 (a suspended
  business is rejected 403 `account_suspended`)

Response shape the app parses: `tokens.access_token` (+ optional
`access_expires_in`, `role`, `business.id`/`business_id`); errors as
`{"error":{"code","message"}}`. Access tokens are **30-day** HS256 JWTs — there is
no refresh flow, so `jwt_ttl_sec` in `config.php` is set long.

### Sync endpoints (Bearer auth; tenant from the JWT `business_id`)
- `POST /api/v1/sync/push` — `{device_id, changes:[{entity,local_id,op,data}]}` →
  `{results:[{entity,local_id,server_id,sync_status,reason}]}`
- `GET  /api/v1/sync/pull?since=<cursor>&device_id=<id>` →
  `{customers:[…], transactions:[…], server_time, has_more}`

Design (matches the app's `lib/sync/` contract, pinned by
`test/sync/http_sync_api_test.dart`):
- **Idempotent** on `(business_id, device_id, local_id)`; the **server id == the
  client's `local_id`** (both UUIDs), so a device pulling back its own pushes is a
  no-op — no client-side id remapping needed.
- **Append-only** (`op:"create"` only). A transaction whose customer hasn't synced
  yet returns `FAILED "unknown customer"` and retries next sync (customers push first).
- **Cursor** = `updated_at DATETIME(6)` (UTC, µs); pull returns rows `> since AND
  <= now` (snapshot taken before the read, so nothing is skipped).
- The `.htaccess` forwards the `Authorization` header (Apache/CGI strips it; PHP
  reads `$_SERVER['HTTP_AUTHORIZATION']`, also `REDIRECT_HTTP_AUTHORIZATION` on
  rewritten paths — `bb_bearer_token` checks all).

### Admin panel (super-admin over the whole platform)
- **UI:** `/admin` — a dependency-free dashboard SPA (`php_backend/admin/index.html`)
  that calls the API below with an admin-scoped Bearer token. Reachable in-app from
  **Settings → About → Admin panel** (`kAdminPanelUrl`), which just opens `/admin`
  in the browser.
- **Auth:** separate `admins` table (bcrypt). `POST /api/v1/admin/login
  {username,password}` issues a JWT with `scope=admin` (**8-hour** TTL). Guards and
  handlers live in `admin_lib.php`.
- **Endpoints** (all admin-scoped): `GET /admin/overview` (KPIs, total outstanding
  credit, 14-day signups, recent activity), `GET /admin/businesses`, `GET
  /admin/business?id=`, `POST /admin/action` (`suspend_business` /
  `unsuspend_business` / `delete_business` / `delete_user` / `reset_password`),
  `GET /admin/audit`.
- Every mutation is written to `admin_audit`. Suspending a business makes its
  users' **login and sync** return 403 (`bb_require_active_business` in `lib.php`).
- **Bootstrap** the first admin once via `admin_setup.php?key=<key>` (choose
  username/password in the browser; it refuses once an admin exists) — **then delete
  it**. The committed key is a placeholder; deploy a fresh key since the repo is public.

### Deploy / update
1. Edit `php_backend/config.php` (DB host/name/user/pass + `jwt_secret`;
   `jwt_ttl_sec` = 2592000 for 30-day tokens).
2. Upload files into the host's `htdocs` via FTP:
   ```bash
   curl --user "<ftp_user>:<ftp_pass>" -T index.php ftp://ftpupload.net/htdocs/index.php
   # …repeat for lib.php, admin_lib.php, config.php, .htaccess, index.html
   curl --user "<ftp_user>:<ftp_pass>" -T admin/index.html ftp://ftpupload.net/htdocs/admin/index.html
   ```
3. Create/upgrade tables once — InfinityFree blocks **remote** MySQL, so run schema
   on the host: import `schema.sql` in phpMyAdmin (all `CREATE TABLE IF NOT EXISTS`,
   safe to re-run), or hit a one-time guarded migration script and delete it. On a
   pre-existing DB the `businesses.status` column needs
   `ALTER TABLE businesses ADD COLUMN status VARCHAR(16) NOT NULL DEFAULT 'active'`
   (MySQL has no `ADD COLUMN IF NOT EXISTS` — guard with an `information_schema` check).
4. `.htaccess` sets `DirectoryIndex index.html index.php` (so `/` serves the landing
   page while `/health`, `/api/*` and `/admin/*` route to PHP) and forwards the
   `Authorization` header for the token-authed endpoints.

> **Testing endpoints from a shell** (not a browser) means solving the anti-bot
> challenge first: fetch the page, extract the three 32-char hex blocks
> (`grep -oE '[0-9a-f]{32}'`), `openssl enc -aes-128-cbc -d -K key -iv iv -nopad`
> → the `__test` cookie, replay with `-b "__test=…"`. A browser does this
> automatically, so the admin SPA's `fetch()` calls just work.

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

## 6. The scale-up backend (.NET + PostgreSQL) — prepared, not deployed

Sync already runs on the PHP backend (§5). `Backend/` is a heavier, production-
shaped alternative for when shared hosting is outgrown: a Clean-Architecture
ASP.NET Core 9 API with JWT auth and PostgreSQL row-level-security tenant
isolation. It is **ready to deploy**; InfinityFree can’t run it. It speaks the same
sync wire contract, so switching is just a `SYNC_BASE_URL` change.

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
1. Bump the version everywhere it appears:
   - `version:` in `Android_App/pubspec.yaml` (e.g. `0.1.21+22`);
   - `kAppVersion` / `kAppBuild` in `Android_App/lib/core/config.dart` (the About
     label in `settings_screen.dart` now reads `kAppVersion`, so it follows along);
   - `android.version` / `android.build` in `php_backend/app_version.php` (this is
     what already-installed apps compare against to offer an **update**, so it must
     equal the new APK's versionName/versionCode);
   - the download caption (version + ~size) in `php_backend/index.html`.
   - **Web-only changes:** also bump `WEB_BUILD` in `php_backend/app/index.html` and
     `web.build` in `app_version.php` so open web sessions get the reload prompt.
2. Build and release (Flutter may not be on PATH — the dev box uses
   `/c/src/flutter/bin/flutter`):
   ```bash
   flutter build apk --release --target-platform android-arm64,android-arm \
     --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
   cp build/app/outputs/flutter-apk/app-release.apk \
     D:/BakiBondhu/Installer/BakiBondhu.apk
   gh release create vX.Y.Z Installer/BakiBondhu.apk \
     --repo mrofiqul/bakibondhu-app --title "BakiBondhu vX.Y.Z" --notes "…"
   ```
   This ARM-focused APK is ~34 MB and installs on any real phone. The GitHub asset
   **must** be named `BakiBondhu.apk`.
3. Deploy the changed host files via FTP: `php_backend/index.html` (caption),
   `app_version.php` (update endpoint), and any changed `app/index.html` / `admin/`
   / PHP. The download button and `…/releases/latest/download/BakiBondhu.apk`
   auto-serve the newest release, so the link itself needs no change.
   > ⚠️ **Deploy paths must not cross:** the landing page `php_backend/index.html`
   > → `/htdocs/index.html`, but the API router `php_backend/index.php` →
   > `/htdocs/index.php`. Uploading the landing over `index.php` makes the whole
   > API 200-serve the landing HTML (`.htaccess` `DirectoryIndex index.html index.php`
   > + rewrite-to-`index.php`). Verify `/health` returns JSON after any deploy.

---

## 8. Data model (essentials)

**Local (SQLite):** `customers(id, name, phone, address, deleted, sync_status, …)`
— `deleted` is a soft-delete tombstone kept until the delete syncs —
`transactions(id, customer_id, type, amount_paisa, due_date, created_at, …)`
append-only, plus `sales`, `collection_activities`, `promise_to_pay`, `sync_meta`.
Balances/aging are computed in Dart from the ledger. The local DB is
**single-tenant** (one shop per device, no `business_id` locally); when a *different*
shop signs in, `LedgerRepository.clearAllData()` + `SyncStore.reset()` wipe it and it
re-pulls from the cloud (tracked by `SettingsStore.dataOwnerBusinessId`). A customer
can be deleted only once their balance is **settled** (no outstanding due), which also
removes their ledger rows locally and on the server.

**Backend (MySQL):**
- `businesses(id, name, timezone, currency, status, thana, zila, expires_at, created_at)`
  — `status` is `active|suspended`; `expires_at DATE NULL` is the subscription end
  (NULL = unlimited), enforced at login/sync (`403 account_expired`). New signups get
  a 30-day trial.
- `users(id, business_id, name, phone UNIQUE, password_hash, role, created_at)`.
- `customers(id, business_id, device_id, local_id, name, phone, address, created_at, updated_at)`
  and `transactions(…, customer_id, type, amount_paisa, due_date, note, updated_at)`
  — the synced ledger; `phone` is UNIQUE per business; idempotent on
  `(business_id, device_id, local_id)`, and `updated_at DATETIME(6)` is the pull cursor.
- `admins(id, username UNIQUE, password_hash, created_at, last_login)` and
  `admin_audit(id, admin_id, action, target, detail, at)`.

Passwords are bcrypt; user tokens are 30-day HS256 JWTs (`sub`, `business_id`,
`role`, `exp`); admin tokens add `scope=admin` (8h).

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| App shows “অ্যাপটি খোলা গেল না” on login/register | Network or the InfinityFree challenge not solved. Confirm the site is up (`/health`), and that the build points at the right `SYNC_BASE_URL`. |
| `400 Bad Request` (openresty) on the cookied retry | Keep-alive reuse — each request must use a fresh connection (already handled in `InfinityFreeClient`). |
| Login returns HTML / `FormatException` | The browser-check page reached the app un-solved; check `InfinityFreeClient` detection (page < 4 KB, contains `toNumbers(`/`slowAES`). |
| APK 404 on the site | InfinityFree deleted it — use the GitHub release URL. |
| Sync returns `401` with a valid login | `Authorization` header not reaching PHP — confirm the `.htaccess` header pass-through is in effect on the host. |
| Sync returns `403 account_suspended` | An admin suspended this business — unsuspend it from `/admin`. |
| Admin `/admin` login fails after setup | The `admins` table is empty (bootstrap not run) or the wrong username/password; re-run `admin_setup.php`. |
| Windows build: “Could not close incremental caches” | `kotlin.incremental=false` in `android/gradle.properties` (already set). |
| Emulator won’t boot / black screen | Kill stale `qemu`/`emulator`, clear `*.lock`, cold-boot with `-gpu swiftshader_indirect`; a corrupt data partition needs `-wipe-data`. |

---

## 10. Roadmap
- **Sync is live** on the PHP backend. If usage outgrows InfinityFree, deploy the
  prepared .NET + Postgres backend (Render + Neon) and repoint `SYNC_BASE_URL` — the
  wire contract is the same.
- Add **refresh tokens** (user tokens are 30-day, admin 8-hour, both non-refreshing)
  and rotate secrets for any real deployment.
- Customer **edits and deletes now sync** (server upsert + `op='delete'` tombstone;
  delete allowed once settled). Still to do: transaction-level edits, richer
  **conflict-resolution** UI, and pushing deletes down to *other* devices via server
  tombstones (today a delete reaches other devices only on reinstall).
- **Shopkeeper web app is live** at `/app` — a static Bangla/English JS SPA
  (`php_backend/app/index.html`) on the same MySQL DB via the sync API (not Flutter
  web). **Excel export, in-app update, and বাংলা/English** ship on both app and web
  (see *Recent features*). Possible next: full localization of the web export headers
  and richer per-language number/date formatting.
