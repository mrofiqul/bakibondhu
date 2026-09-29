# বাকিবন্ধু · BakiBondhu

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Live site](https://img.shields.io/badge/Live-bakibondhu.infinityfreeapp.com-blue.svg)](https://bakibondhu.infinityfreeapp.com)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-brightgreen.svg)](https://github.com/mrofiqul/bakibondhu-app/releases/latest)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg)](https://flutter.dev)

A **Bangla-first, offline-first credit-ledger (baki) app** for Bangladeshi micro-merchants —
keep customers' *baki* (credit) and payments with ease, even without internet. Runs as an
**Android app** and as a **web app** on the same account.

**Topics:** `flutter` · `dart` · `android` · `offline-first` · `bangla` · `bangladesh` ·
`ledger` · `sqlite` · `php` · `mysql` · `fintech` · `small-business`

- **Android app:** Flutter/Dart (works fully offline; local SQLite)
- **Web app:** static Bangla/English SPA at `/app`, sharing the same cloud database
- **Backend (live):** PHP + MySQL on InfinityFree — auth, cloud **sync**, and a web **admin panel**
- **Alternative sync backend (prepared, not deployed):** ASP.NET Core 9 + PostgreSQL

### ✨ Features

Customer **credit & payments** ledger · **daily sales** tracking (day/month/quarter/year) ·
**SMS/WhatsApp reminders** · **collections & payment promises** · **cloud sync + backup** ·
**Bangla / English** (English by default outside Bangladesh) · **country-based registration** ·
**Excel (.xlsx) report** of all customers · in-app **update** · **subscription** (30-day free
trial, ৳100/mo in Bangladesh · $1.20/mo outside) · fully **offline-first**.

### 📲 Use it now

- **Install the app:** [latest APK](https://github.com/mrofiqul/bakibondhu-app/releases/latest/download/BakiBondhu.apk) (Android)
- **Use it in a browser:** https://bakibondhu.infinityfreeapp.com/app
- **Website:** https://bakibondhu.infinityfreeapp.com · **[Privacy policy](https://bakibondhu.infinityfreeapp.com/privacy.html)**

---

## 📖 Documentation

- **[Developer Manual](docs/DEVELOPER_MANUAL.md)** — architecture, local setup,
  backends (PHP+MySQL and .NET+Postgres), the InfinityFree browser-check client,
  release & distribution, data model, and troubleshooting.
- **User Manual — [বাংলা](docs/USER_MANUAL_BN.md)** · **[English](docs/USER_MANUAL_EN.md)**
  — step-by-step guide for shopkeepers (install, credit/payments, sales, reminders,
  collections, subscription, logout).
- **[Owner's Manual](BakiBondhu_Owner_Manual.html)** · **[Web-app Guide](BakiBondhu_Web_Guide.html)**
  — HTML guides (sources under [`docs/owner-manual/`](docs/owner-manual/) and
  [`docs/web-guide/`](docs/web-guide/)); the owner manual is also served at `/manual/`.

**Distribution & operations**

- **[Free distribution](docs/FREE_DISTRIBUTION.md)** — website + GitHub + in-app updater
  (live), and the F-Droid submission (metadata ready).
- **[Google Play prep](docs/PLAY_STORE.md)** — release signing, App Bundle, store
  listing, data-safety answers, and the console checklist.
- **[Tracking & status](docs/TRACKING.md)** — how to check users, version, downloads,
  and server health ([HTML version](docs/tracking.html); `scripts/status.sh` for a
  one-command check).
- Store metadata + graphics: [`Android_App/fastlane/metadata/`](Android_App/fastlane/metadata/)
  and [`docs/store-assets/`](docs/store-assets/).

Formal specifications live in [`documents/`](documents/) (app, database, REST API,
offline sync, QA, DevOps).

## 🗂 Repository layout

| Path | What |
|---|---|
| `Android_App/` | Flutter app (the product) + `fastlane/` store metadata |
| `php_backend/` | PHP + MySQL backend — auth, sync, admin, and the web app (`app/`) |
| `Backend/` | ASP.NET Core 9 + PostgreSQL (prepared, not deployed) |
| `documents/` | Formal specifications |
| `docs/` | Manuals + distribution, Play Store, and tracking guides |
| `scripts/` | Helper scripts (e.g. `status.sh`) |

## 🚀 Quick start (app)

```bash
cd Android_App
flutter pub get
flutter run -d <device>

# release APK (ARM only, ~34 MB) — the backend URL now defaults to production,
# so the --dart-define is optional (kept explicit here):
flutter build apk --release --target-platform android-arm64,android-arm \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com

# App Bundle (.aab) for the Play Store (needs android/key.properties — see docs):
flutter build appbundle --release \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
```

See the **[Developer Manual](docs/DEVELOPER_MANUAL.md)** for backend deployment,
the release process, and everything else.
