# Android App — Setup & first run

This folder already contains the **domain layer** (the pure business logic the
whole app is built on) and its **unit tests**. To run them and continue building,
install the Flutter toolchain, generate the platform scaffold, then run the tests.

## 1. Install Flutter (one time)

Windows, using winget:

```bash
winget install --id Flutter.Flutter -e
```

(Or follow https://docs.flutter.dev/get-started/install/windows.) Then check it:

```bash
flutter doctor
```

`flutter doctor` will tell you what's missing (e.g. Android Studio + Android SDK
for building on a device). For **running the unit tests below you do not need the
Android SDK** — the Dart test runner is enough.

## 2. Generate the platform scaffold

`flutter create` fills in the platform folders (`android/`, `ios/`, etc.) and the
app entry point **without touching** the `lib/` and `test/` files already here:

```bash
flutter create . --org com.bakibondhu --platforms=android --project-name bakibondhu
```

## 3. Get packages

```bash
flutter pub get
```

## 4. Run the tests (the important step)

```bash
flutter test
```

You should see the domain tests pass — including the `F-ALLOC-*` allocation
fixtures from the QA spec (§13) and the balance/aging checks. These prove the
money math is correct before any UI exists.

## What's here already

```
lib/domain/
  money.dart        Money value object (integer paisa — no floating point)
  models.dart       Customer, TxnEntry, TxnType (+ balance sign)
  balance.dart      customerBalance = Σ amount × sign; totalOwed (positives only)
  allocation.dart   reallocateCustomer — FIFO payment→credit (mirrors DB §13c)
  aging.dart        customerAging — buckets on UNPAID credit, business-tz aware
test/domain/
  allocation_test.dart   QA fixtures F-ALLOC-01..08
  balance_test.dart      money formatting + balance rules
```

## Next steps (suggested order)

1. **Data layer** (`lib/data/`): SQLite tables mirroring the schema, plus
   repositories that read/write `Customer` and `TxnEntry` and compute balances
   locally (offline-first).
2. **Screens 1 & 2** (`lib/features/dashboard`, `lib/features/customers`): Home
   total + Customer detail, in Bangla, fully offline.
3. **Add transaction, reminder, first-run**, then the sync engine (`lib/sync/`).

See `../documents/BakiBondhu_Android_UIUX_Specification` for the screen specs and
`../documents/BakiBondhu_Offline_Sync_Technical_Design` for the sync/allocation design.
