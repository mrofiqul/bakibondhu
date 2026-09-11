# বাকিবন্ধু · BakiBondhu

A **Bangla-first, offline-first credit-ledger app** for Bangladeshi micro-merchants —
keep customers' *baki* (credit) and payments with ease, even without internet.

- **Android app:** Flutter/Dart (works fully offline; local SQLite)
- **Auth backend:** PHP + MySQL, hosted on InfinityFree
- **Sync backend (prepared):** ASP.NET Core 9 + PostgreSQL

**Live site:** https://bakibondhu.infinityfreeapp.com · **Download the app:**
[latest APK](https://github.com/mrofiqul/bakibondhu-app/releases/latest/download/BakiBondhu.apk)

---

## 📖 Documentation

- **[Developer Manual](docs/DEVELOPER_MANUAL.md)** — architecture, local setup,
  backends (PHP+MySQL and .NET+Postgres), the InfinityFree browser-check client,
  release & distribution, data model, and troubleshooting.
- **User Manual — [বাংলা](docs/USER_MANUAL_BN.md)** · **[English](docs/USER_MANUAL_EN.md)**
  — step-by-step guide for shopkeepers (install, credit/payments, reminders,
  collections, logout).
- Formal specifications live in [`documents/`](documents/) (app, database, REST API,
  offline sync, QA, DevOps).

## 🗂 Repository layout

| Path | What |
|---|---|
| `Android_App/` | Flutter app (the product) |
| `php_backend/` | PHP + MySQL auth backend (deployed to InfinityFree) |
| `Backend/` | ASP.NET Core 9 + PostgreSQL (prepared for real sync) |
| `documents/` | Formal specifications |
| `docs/` | Developer + user manuals |

## 🚀 Quick start (app)

```bash
cd Android_App
flutter pub get
flutter run -d <device>
# release build pointed at the live backend:
flutter build apk --release --split-per-abi \
  --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
```

See the **[Developer Manual](docs/DEVELOPER_MANUAL.md)** for backend deployment,
the release process, and everything else.
