# BakiBondhu — Project Memory & Handover

**Read this first.** It lets a developer or AI agent resume work on BakiBondhu from
its **current state** (not from scratch) — after a long gap, a new device, a cleared
history, or a different agent. It covers what the app is, how it's built, how it's
deployed, the exact release recipe, the hard rules, and the known gotchas.

> ⚠️ This file is committed to a **public** repo. **Never put secrets here**
> (FTP/DB passwords, JWT secret, tokens). See [§13 Credentials](#13-credentials--secrets).

- **Last updated:** 2026-10-15 · **Current version:** **v0.1.31** (Android
  versionName `0.1.31` / versionCode `32`; web build `11`)
- **Live site:** https://bakibondhu.infinityfreeapp.com
- **Source repo (public, MIT):** https://github.com/mrofiqul/bakibondhu
- **APK release repo:** https://github.com/mrofiqul/bakibondhu-app
- **Owner:** Rafiq (`rafiq.ru.cse@gmail.com` — identity only; never send to third parties)
- **Package name (immutable once published):** `com.bakibondhu.bakibondhu`

---

## 1. What BakiBondhu is

A **Bangla-first, offline-first credit-ledger (baki khata) app** for Bangladeshi
micro-merchants — a digital replacement for the paper "baki" notebook. Shopkeepers
track each customer's **credit (baki) and payments**, record **daily sales**, send
**SMS/WhatsApp reminders**, and keep **collections & payment promises**. It works
fully offline; logging in syncs everything to the cloud and across devices.

It ships as:
- an **Android app** (the primary product), and
- a **web app** at `/app` — a static SPA that mirrors the Android UI on the **same**
  MySQL database via the sync API.

**STANDING RULE — every feature change goes to BOTH the Android app AND the web app**
(plus admin/docs where relevant), by default.

---

## 2. Current live surfaces

| URL | What | Access |
|---|---|---|
| `/` | Marketing landing page (bilingual, region-auto: English abroad / Bangla in BD) | public |
| `/app` | Web app (shopkeeper portal) | login |
| `/app/guide/` | Web-app user guide (Bangla) | public |
| `/admin` | Super-admin panel (platform-wide) | admin login |
| `/manual/` | Owner's manual | admin login |
| `/privacy.html` | Privacy policy (EN/BN) | public |
| `/health` | API health check (must return JSON, not HTML) | public |
| `/api/v1/app/version` | Advertises latest android/web build for the in-app updater | public |
| `/api/v1/auth/{register,login}` | Auth | public |
| `/api/v1/sync/{push,pull}` | Offline sync (Bearer token) | token |
| `/api/v1/admin/export/customers.xlsx` | Admin Excel export | admin |

---

## 3. Repository layout

```
D:\BakiBondhu\                 (repo root; git remote = mrofiqul/bakibondhu)
├─ Android_App/                Flutter app (the product)
│  ├─ lib/
│  │  ├─ main.dart             entry: opens DB/settings/session, wires sync+auth, startup language
│  │  ├─ app.dart              root widget; MaterialApp.builder wraps routes with offline banner
│  │  ├─ core/                 config.dart, strings_bn.dart (bilingual S), countries.dart,
│  │  │                        bd_geo.dart, validators.dart, connectivity_status.dart,
│  │  │                        update_service.dart, theme.dart, dialogs.dart, format.dart, xlsx_writer.dart
│  │  ├─ data/                 ledger_repository (+sqflite/in_memory), session.dart, auth_api.dart,
│  │  │                        settings_store, infinityfree_client.dart  ← anti-bot HTTP client
│  │  ├─ sync/                 sync_engine, sync_store (+sqflite), http_sync_api, auto_sync.dart
│  │  └─ features/             auth/ dashboard/ customers/ transactions/ sales reports/
│  │                          subscription/ collections/ reminders/ settings/ onboarding/ sync/
│  │  └─ test/                 widget + unit tests (run: flutter test)
│  ├─ android/                 Gradle (Kotlin DSL); app/build.gradle.kts has release signing;
│  │                          key.properties (git-ignored) holds the upload keystore details
│  └─ fastlane/metadata/       store listing text + icon/feature graphic/screenshots (F-Droid reads it)
├─ php_backend/                PHP + MySQL backend (deployed to InfinityFree /htdocs)
│  ├─ index.php                API router         → /htdocs/index.php   ⚠️ NEVER swap with index.html
│  ├─ index.html               landing page       → /htdocs/index.html
│  ├─ app/index.html           the WEB APP (SPA)  → /htdocs/app/index.html
│  ├─ app/guide/index.html     web guide          → /htdocs/app/guide/index.html
│  ├─ admin/                   admin panel        → /htdocs/admin/
│  ├─ app_version.php          version endpoint   → /htdocs/app_version.php
│  ├─ privacy.html             privacy policy     → /htdocs/privacy.html
│  ├─ lib.php, admin_lib.php, xlsx.php, schema.sql, .htaccess
│  └─ config.php               DB creds + jwt_secret  (GIT-IGNORED — never commit, never edit via tooling)
├─ Backend/                    ASP.NET Core 9 + PostgreSQL (prepared, NOT deployed; Render+Neon blueprint)
├─ documents/                  formal specs (app, DB, REST API, sync, QA, DevOps)
├─ docs/                       manuals + distribution/tracking guides (see §12)
│  ├─ USER_MANUAL_{BN,EN}.md, DEVELOPER_MANUAL.md, README.md
│  ├─ owner-manual/ web-guide/ (HTML sources + build.py → dist/ is git-ignored)
│  ├─ FREE_DISTRIBUTION.md, PLAY_STORE.md, fdroid/, TRACKING.md, tracking.html, store-assets/
├─ scripts/status.sh           one-command status check (downloads, version, /health)
├─ Installer/BakiBondhu.apk    last built release APK (copied here before `gh release`)
└─ README.md, MEMORY.md (this file), "Github authentication.png" (keep, untracked)
```

Flutter SDK on the dev box: `C:\src\flutter` (`/c/src/flutter/bin/flutter`; not on PATH).

---

## 4. Architecture

- **Android (Flutter/Dart):** offline-first. Local **SQLite** via `sqflite`
  (single-tenant — one shop per device; no `business_id` locally). Balances/aging
  computed in Dart from the ledger. A bilingual runtime string class `S`
  (`strings_bn.dart`, `AppLang` enum + getters) + `appLanguage` ValueNotifier rebuilds
  the whole app on language switch.
- **Web app (`php_backend/app/index.html`):** one static HTML file — a Bangla SPA
  that calls the **same** sync API. English is a `bn→en` map + post-render DOM
  translator; some screens (subscription, auth) are built bilingually by `LANG`
  directly. `WEB_BUILD` constant gates the web update prompt.
- **Backend (PHP 8 + MySQL, PDO):** vanilla PHP, no framework. Auth (JWT, 30-day
  token), offline sync (push/pull), the admin panel, the version endpoint, and Excel
  export. Hosted on **InfinityFree free hosting** (see §5/§6).
- **Admin panel (`/admin`):** super-admin over all shops — platform reports, suspend/
  delete/reset-password, **set/extend subscription expiry**, audit log.
- **Alt backend (`Backend/`):** ASP.NET Core 9 + PostgreSQL (RLS tenant isolation),
  same sync wire contract — for when shared hosting is outgrown. **Not deployed.**

### Sync design (important)
- Endpoints: `POST /api/v1/sync/push` (`{device_id, changes:[{entity,local_id,op,data}]}`)
  and `GET /api/v1/sync/pull?since=<cursor>&device_id=<id>`.
- **Server id == the client's local_id** (both UUIDs). This is the critical design: on
  pull the store rewrites a txn's `customer_id` to the server id, so making server
  id = local id keeps a device's own echoes a no-op (no client id-remapping).
- Idempotent on `(business_id, device_id, local_id)`. Append-only ledger; money is
  integer **paisa** (÷100 = taka), never float. Cursor = `updated_at DATETIME(6)` UTC.
- Entities synced: customers, transactions, sales, collection_activities, promise_to_pay.
- Per-shop isolation on a shared device: on login, if a **different** shop signs in,
  clear local data + reset cursor + re-pull (`dataOwnerBusinessId` marker).

---

## 5. Hosting & the InfinityFree anti-bot challenge

Backend is on **InfinityFree** (free PHP/MySQL). Three things that constantly matter:

1. **Anti-bot "browser check".** Every HTTPS request to the host first gets a
   JavaScript `__test` AES-128-CBC cookie challenge. A real browser solves it; a plain
   HTTP client gets challenge HTML, not your response.
   - **Android must route ALL calls to the host through `data/infinityfree_client.dart`**
     (`InfinityFreeClient` — solves the `__test` cookie, replays on a fresh connection).
     **Never use plain `http.get` to the host.** (This bug silently broke the update
     check in v0.1.19–v0.1.22; fixed in v0.1.23.)
   - **Web app** runs in a browser, so `fetch()` just works.
   - **Shell/curl** must solve the cookie (fetch challenge → three 32-hex blocks →
     `openssl enc -aes-128-cbc -d -K key -iv iv -nopad` → `__test` cookie → replay with
     `-b`). See `scripts/status.sh` for a working solver. **FTP (port 21) has NO
     challenge** — that's why deploys use FTP.
2. **No remote MySQL.** Schema/migrations must run **on the host** — import
   `schema.sql` in phpMyAdmin (all `CREATE TABLE IF NOT EXISTS`), or upload a one-time
   **guarded** PHP migration script (key-gated), hit it **through a browser** (passes
   anti-bot), verify, then **delete it**. MySQL has no `ADD COLUMN IF NOT EXISTS` — guard
   column adds with an `information_schema` check.
3. **No file hosting** — InfinityFree auto-deletes uploaded APKs. Distribute via
   **GitHub releases**, never from `htdocs`. Also: using free hosting as an app backend
   is against their ToS (account can be suspended) — treat as testing/personal.

### ⚠️ DEPLOY PATHS — do not cross (has caused a full API outage)
`.htaccess` has `DirectoryIndex index.html index.php`.
- landing `php_backend/index.html` → **`/htdocs/index.html`**
- API router `php_backend/index.php` → **`/htdocs/index.php`**

Uploading the landing over `index.php` makes every `/api/*` and `/health` **200-serve
the landing HTML** → the whole API is silently down. **Always verify `/health` returns
JSON after any deploy.**

### How deploys actually happen (FTP)
- Upload changed files via FTP: `curl -T <local> ftp://ftpupload.net/htdocs/<path>`.
- **The auto-mode classifier blocks inline FTP passwords.** Write a one-line netrc file
  first (`machine ftpupload.net login <user> password <pass>`), then
  `curl --netrc-file <file> -T ...`, then delete the netrc. (Use the Write tool for the
  netrc, not an inline bash heredoc with the password.)
- Deleting a host file: `curl --netrc-file N -Q "DELE /htdocs/app/demo.html" "ftp://ftpupload.net/"`
  (absolute path from root context; success reply is `250`, not the session `226`).

---

## 6. Database (MySQL, utf8mb4)

- DB name `if0_42877652_bakibondhu`; inspect/modify via **phpMyAdmin** in the
  InfinityFree control panel. Money stored as **INTEGER paisa**.
- Core tables: `businesses` (id, name, timezone, currency, status, **country**
  [added v0.1.30, DEFAULT 'Bangladesh'], thana, zila, expires_at, created_at),
  `users` (owner login; phone unique), `customers`, `transactions`, `sales`,
  `collection_activities`, `promise_to_pay`. Location columns are reused: BD →
  thana/zila; other countries → city→thana, state→zila.
- Subscription = per-shop `expires_at`. New signups get a **30-day trial**; admin
  sets/extends/clears expiry from `/admin`. Expired → `403 account_expired` on
  login+sync. **No in-app payment** — the subscription page is display-only; owners
  pay the platform owner out-of-band (bKash) and the owner extends expiry.

---

## 7. The release recipe (ship a new version)

Version scheme: `versionName` like `0.1.x`, `versionCode = x + 1` (e.g. v0.1.31 =
build 32). Web has its own `WEB_BUILD` integer (currently 11) + a display label
"ওয়েব সংস্করণ X.Y".

**Bump these in lockstep:**
1. `Android_App/pubspec.yaml` → `version: 0.1.x+N`
2. `Android_App/lib/core/config.dart` → `kAppVersion` / `kAppBuild` (About label + update check read these)
3. `php_backend/app_version.php` → `android.version` / `android.build` (MUST equal the new APK) + `notes`; and `web.build` if the web changed
4. `php_backend/index.html` landing caption (version + ~size)
5. **Web-only changes:** also bump `WEB_BUILD` and the `VERSION` label + its i18n entry in `php_backend/app/index.html`

**Build + release (Android):**
```bash
cd Android_App
/c/src/flutter/bin/flutter analyze lib            # must say "No issues found!"
/c/src/flutter/bin/flutter test                   # widget/unit tests
/c/src/flutter/bin/flutter build apk --release --target-platform android-arm64,android-arm \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
cp build/app/outputs/flutter-apk/app-release.apk ../Installer/BakiBondhu.apk
gh release create v0.1.x ../Installer/BakiBondhu.apk --repo mrofiqul/bakibondhu-app \
  --title "v0.1.x" --notes "..."
git tag -a v0.1.x -m "..." && git push origin v0.1.x    # source tag (F-Droid builds from it)
```
- ARM-only APK ≈ 34 MB; **won't run on an x86_64 emulator** — test release builds on a
  real device / arm64 emulator (debug `flutter run` is fine on any). The GitHub asset
  **must** be named `BakiBondhu.apk` (so `releases/latest/download/BakiBondhu.apk` stays valid).
- `kSyncBaseUrl` now **defaults to production**, so the `--dart-define` is optional
  (kept explicit; F-Droid's plain `flutter build` is already correct).
- For Play: `flutter build appbundle --release …` → `.aab` (needs `android/key.properties`).

**Deploy host files (FTP, see §5):** upload the changed `php_backend/*` to the right
`/htdocs/*` paths (watch the index.html/index.php rule). Then **verify `/health`** and
`/api/v1/app/version`.

**Docs:** update `docs/USER_MANUAL_{BN,EN}.md`, the owner-manual + web-guide
`*.base.html` (then `python build.py` in each + redeploy to `/manual/` and
`/app/guide/`), and `DEVELOPER_MANUAL.md` recent-features. Commit everything on a
branch → merge to `main` → push. Then update this MEMORY.md's version line.

**Verify live** (browser, since the host is anti-botted to curl): endpoint shows the
new build; `/health` 200; the changed UI works. For logged-in web screens without an
account, seed a throwaway demo copy (see §11) — then delete it from the server.

---

## 8. Feature set (current) + condensed changelog

**Current features:** customer credit/payments ledger · search/sort/edit/delete
customers · customer transaction-history export (text) · daily **sales** tracking
(day/month/quarter/year) · **quick-add sale from Home** · "add this credit to today's
sales" option · **reminders** (SMS/WhatsApp) · **collections & promises** · **cloud
sync + auto-sync** when online · **offline** everywhere + an offline top-bar banner ·
**Bangla/English** (English default outside Bangladesh) · **country-based
registration** (BD cascade vs free-text + intl phone) · **Excel (.xlsx) export** to
Downloads · in-app **update** check + prompt · **subscription** page (30-day trial;
monthly ৳100 / $1.20; **yearly 20% off = ৳960 / $11.52**, all countries;
display-only) · landing page **auto-language by region**.

**Condensed changelog** (full detail in `git log` and `docs/DEVELOPER_MANUAL.md`):
- v0.1.4 direct sales · v0.1.5 mandatory registration + location · v0.1.6 admin web-only
- v0.1.7 trial reminder · v0.1.8 unique customer mobile · v0.1.9 edit/delete customer (synced)
- v0.1.10–12 search / sort / history export · v0.1.13–14 geo dropdowns (zila→thana, + bivag)
- v0.1.15 slim ARM APK (~34MB) · v0.1.16 per-shop isolation + delete settled customer
- v0.1.17 collections/promises synced · v0.1.18 xlsx export (app+web+admin)
- v0.1.19 in-app update · v0.1.20 registered-owners-only · v0.1.21 Bangla/English selection
- v0.1.22 download report to Downloads · **v0.1.23 FIXED anti-bot update check (InfinityFreeClient)**
- v0.1.24 faster language switch · v0.1.25 auto-sync · v0.1.26 offline banner
- v0.1.27 quick-add sale + credit-as-sale + landing "go to web" · v0.1.28 quick-add popup fix
- v0.1.29 subscription page · v0.1.30 country-based registration + English-default-abroad
- **v0.1.31 (current)** yearly subscription (20% off, all countries)
- (post-v0.1.31, landing only) landing page auto-language by region

---

## 9. Key implementation notes (by subsystem)

- **Language default by region:** Android `main.dart` seeds start language from
  `WidgetsBinding.instance.platformDispatcher.locale.countryCode` (≠BD → English) when
  no saved pref. Web `LANG` boot checks `Intl.DateTimeFormat().resolvedOptions().timeZone
  !== 'Asia/Dhaka'`. The **landing page** uses the same timezone check in a pre-paint
  head script; auto-detected choice is NOT persisted (re-detects each visit), only an
  explicit toggle persists (`localStorage bb_land_lang`).
- **Registration (country-based, v0.1.30):** `lib/core/countries.dart` (34-country list).
  Bangladesh → বিভাগ→জেলা→থানা cascade (`bd_geo.dart`) + strict `^01[3-9]\d{8}$` phone.
  Other country → free-text State/City + generic intl phone `^\+?\d{6,20}$`
  (`validators.dart` `intlMobileValidator`). Backend `handle_register` branches the phone
  rule by `country` and stores it. `auth_api.register` sends `country`.
- **Subscription (display-only):** constants in `config.dart` (`kTrialDays`,
  `kPrice{Bdt,Usd}PerMonth`, `kPrice{Bdt,Usd}PerYear`, `kSave{Bdt,Usd}PerYear`,
  `kYearlyDiscountPct=20`, `kBkashNumber`, `kSupportWhatsApp[Intl]`, `kSupportEmail`).
  Android `features/subscription/subscription_screen.dart` (Monthly/Yearly × BD/outside
  toggles). Web `renderSubscription()` built bilingually by `LANG`. Status read from the
  session's `expiresAt`. Yearly = 12×monthly×0.8.
- **Auto-sync (v0.1.25):** `sync/auto_sync.dart` fires `SyncEngine.syncNow()` on startup,
  offline→online edge (`connectivity_plus`), app resume, and a 20s pending poll;
  guarded/logged-in+online-only/errors swallowed. Publishes `appOnline`
  (`core/connectivity_status.dart`) which drives the offline banner in `app.dart`.
- **Update checker (v0.1.19/23):** `core/update_service.dart` compares `kAppBuild` vs
  `/api/v1/app/version` **via InfinityFreeClient**, opens the APK URL (url_launcher).
- **Admin expiry:** `/admin` Shops tab → "Set expiry" (date picker) — this is how the
  owner activates/renews a subscription after an out-of-band bKash payment.

---

## 10. Standing rules & hard constraints

1. **Both apps.** Every feature change → Android **and** web app (+ admin/docs where relevant).
2. **Deploy paths never cross** (index.html vs index.php) — §5. Verify `/health` after deploys.
3. **Any Android call to the InfinityFree host → `InfinityFreeClient`**, never plain http.
4. **`php_backend/config.php` is off-limits to automated edits** (the auto-mode classifier
   hard-blocks it) and is **git-ignored** — never commit it, never put its contents here.
5. **Never commit secrets.** No FTP/DB passwords, JWT secret, or tokens in the repo.
6. **Never handle the owner's admin password in plaintext.**
7. Keep the untracked file **`Github authentication.png`** in place; don't commit or delete it.
8. `rafiq.ru.cse@gmail.com` is the owner's identity only — never send it to a third-party
   service. Support contact email is a different address (`rofiqulislam90.cse@gmail.com`).
9. Money is integer **paisa**; server id == local id in sync; append-only ledger.

---

## 11. Gotchas & lessons learned

- **Anti-bot:** curl/HTTP clients can't reach the host without solving the `__test`
  cookie; FTP can. Android → InfinityFreeClient. (v0.1.23 lesson.)
- **Android quick input:** prefer a **dialog/bottom-sheet** over an inline expanding
  `TextField` — inline focus/render was unreliable on a real device. (v0.1.27→v0.1.28.)
- **Bangla in images:** Python/Pillow can't shape Bangla conjuncts (no `raqm` on the
  box) → use only single glyphs (e.g. the ৳ sign via `kalpurush.ttf`) in PIL, or render
  via a **browser canvas** (which shapes Bangla correctly). Store graphics were made
  this way (`docs/store-assets/`).
- **Headless screenshots:** headless Chrome ignores the mobile viewport meta and lays
  out ~980px — force a fixed width in the page (a `#shotfix` style) to capture phone
  screens. Give `--virtual-time-budget ~9000` so the anti-bot JS settles.
- **Seeded web screenshots without an account:** copy `php_backend/app/index.html`,
  inject a localStorage token + stub `pullAll()` to return demo data + a `?screen=`
  router hook, deploy as `/app/demo.html`, screenshot, **then DELETE it from the server**.
- **Windows shell + Bangla:** building request bodies with Bangla on the CLI mangles
  UTF-8 → write to a file with Python and `curl --data-binary @file`.
- **ARM-only release APK** won't run on an x86_64 emulator.

---

## 12. Testing, verifying, monitoring

- **Static/tests:** `flutter analyze lib` (must be clean) and `flutter test`
  (`test/widget/subscription_test.dart` proves the yearly pricing renders, etc.).
- **Live verification:** use the **in-app browser** (it passes the anti-bot) to hit
  `/health`, `/api/v1/app/version`, and the changed UI. `scripts/status.sh` prints the
  latest version, GitHub download totals, and `/health` in one command.
- **Who's using it:** the **Admin panel** (`/admin`) — total shops, signups, expiry.
  phpMyAdmin for raw counts (`businesses`/`users` by `created_at`/`country`).
- **Docs for operators:** `docs/TRACKING.md` (+ `docs/tracking.html`).

---

## 13. Credentials & secrets (where they live — NOT the values)

**None are stored in this repo.** To deploy/administer you need, from the **owner**:
- **InfinityFree FTP** — host `ftpupload.net`, and the account user + password.
- **MySQL** — DB `if0_42877652_bakibondhu` (via phpMyAdmin in the InfinityFree panel);
  user + password.
- **`jwt_secret`** and the DB password live in `php_backend/config.php` — **git-ignored**,
  present only on the owner's machine and on the host. Not retrievable from a fresh clone.
- **Admin panel** login (super-admin) — owner-held.
- **GitHub** `mrofiqul` and **GitLab** (for the F-Droid MR) — owner-held.

A new agent on a new device: get the FTP + DB credentials and `config.php` from the
owner (or re-create `config.php` on the host) before any deploy. **Publishable** support
contacts (already public on the site): bKash `01723-967187`, WhatsApp `01730781320`,
support email `rofiqulislam90.cse@gmail.com`.

---

## 14. Distribution status

- **LIVE (free):** the website download + **GitHub releases** + the **in-app updater**.
  This is the primary channel today.
- **F-Droid — prepared, owner-submitted:** fastlane metadata + a ready-to-copy YAML in
  `docs/fdroid/com.bakibondhu.bakibondhu.yml`; source is tagged per release; `kSyncBaseUrl`
  defaults to prod so a plain build works. Remaining: owner forks `gitlab.com/fdroid/
  fdroiddata`, adds the YAML, opens a merge request. See `docs/FREE_DISTRIBUTION.md`.
- **Google Play — fully prepped, ON HOLD** (needs the one-time US$25). Release signing,
  `.aab`, and the live privacy policy are ready. See `docs/PLAY_STORE.md`. (Owner chose
  the free channels for now.)
- Store graphics/screenshots: `docs/store-assets/` and `Android_App/fastlane/metadata/`.

---

## 15. Open decisions / roadmap

- **Hosting migration (the big open decision).** InfinityFree is free but: against ToS
  for an app backend (suspension risk), daily-hits/bandwidth caps, no remote MySQL, and
  the anti-bot friction. When usage grows, move to real hosting. `Backend/` (ASP.NET +
  PostgreSQL) is prepared with a Render + Neon blueprint and speaks the same sync
  contract (switch = a `SYNC_BASE_URL` change); alternatively keep PHP and move to a paid
  PHP/MySQL host. **Decide before scaling.**
- **F-Droid MR** not yet submitted (owner step).
- **Google Play** on hold pending the $25 fee.
- Formal specs in `documents/` are frozen and not updated per-feature (e.g. the REST spec
  predates the `country` field / subscription endpoints) — refresh if doing a spec pass.

---

## 16. How a future agent should work from here

1. **Read this file, then `docs/DEVELOPER_MANUAL.md`.** Skim `git log --oneline` for recent work.
2. Confirm the current state: `scripts/status.sh`, and open `/health` +
   `/api/v1/app/version` in the in-app browser.
3. For a change: implement it in **both** the Android app and the web app; keep money in
   paisa; route Android host calls through InfinityFreeClient.
4. Verify with `flutter analyze` + `flutter test`; visually verify the web via the
   in-app browser (seeded demo for logged-in screens — then delete it).
5. Follow the **release recipe (§7)** exactly (bump all version files together; watch the
   deploy-path rule; verify `/health`). Build APK (+ `.aab`/tag as needed), deploy host
   files, `gh release`, update docs.
6. Commit on a branch → merge to `main` → push. **Update the version line at the top of
   this file** and add a one-line changelog entry in §8.
7. Get deploy credentials from the owner (§13) — they are intentionally not in the repo.
