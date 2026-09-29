# Publishing BakiBondhu to Google Play

This is the step-by-step for getting BakiBondhu onto the Google Play Store. The
**repo is prepared** (release signing config, App Bundle build, privacy policy);
what remains are the account, keystore, graphics, and console steps — most of
which only you can do from your own Google account.

- **Package name (immutable once published):** `com.bakibondhu.bakibondhu`
- **Current version:** v0.1.30 (versionCode 31) — Play tracks the versionCode.
- **Privacy policy URL:** https://bakibondhu.infinityfreeapp.com/privacy.html
- **Min / target SDK:** minSdk 24 (Android 7.0) · targetSdk 36 (meets Play's rule)

---

## 1. What only you can do (account & legal)

1. **Create a Google Play Developer account** at https://play.google.com/console —
   one-time **US$25** fee, and you must verify identity (this can take a few days).
   *(I can't create the account or pay the fee.)*
2. **Accept** the Developer Distribution Agreement.
3. Keep the **upload keystore + its passwords** backed up somewhere safe (see §3).
   Losing them means you can't publish updates.

## 2. Build the App Bundle (.aab) — Play needs this, not the APK

Play Store accepts an **Android App Bundle (`.aab`)**, not the `.apk` we host on
GitHub. The repo now builds one; it just needs your release keystore (§3). Build:

```bash
cd Android_App
flutter build appbundle --release --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
```

Output: `Android_App/build/app/outputs/bundle/release/app-release.aab` — this is
the file you upload to the console.

> Without `android/key.properties` present the release build falls back to the
> **debug** key (fine for local testing, **rejected by Play**). Do §3 first.

## 3. Create your upload keystore (once) — you hold the password

Run this once (anywhere; then move the `.jks` somewhere safe and back it up):

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for a password and a few details (name/org/city — any real values).
Then create `Android_App/android/key.properties` (this file is git-ignored —
never commit it) from `key.properties.example`:

```
storePassword=THE_PASSWORD_YOU_JUST_SET
keyPassword=THE_SAME_OR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Now `flutter build appbundle --release …` (§2) produces a properly signed `.aab`.

> **Play App Signing** (recommended, default): Google holds the real app-signing
> key; you sign uploads with *this* upload key. Enrolling is a checkbox when you
> create the app. Keep this upload keystore for every future update.

## 4. Store listing (copy you can paste)

**App name** (≤30 chars) — pick one:
- `বাকিবন্ধু — BakiBondhu`
- `BakiBondhu: Credit Ledger`

**Short description** (≤80 chars):
> Offline baki-khata & sales ledger for shopkeepers — Bangla & English.

**Full description** (≤4000 chars):
> BakiBondhu is a simple, Bangla-first credit ledger (baki khata) for small
> shopkeepers — an easy replacement for the paper notebook.
>
> ✅ Works offline — your records stay on your phone, no internet needed for daily use.
> ✅ Bangla & English — switch anytime; opens in English outside Bangladesh.
> ✅ Track customer credit (baki) & payments — see who owes how much at a glance.
> ✅ Record daily sales — with day / month / quarter / year totals.
> ✅ Send polite reminders over SMS or WhatsApp.
> ✅ Cloud sync & backup — log in and your ledger is safe and available on any phone or in the web app.
> ✅ Download an Excel report of all your customers.
> ✅ Collections & payment promises to follow up dues.
>
> Free 30-day trial for every new account. Simple monthly subscription after that.
>
> Made for the corner shop, the grocery, the pharmacy — anyone who keeps "baki".

**Category:** Finance (or Business) · **Type:** App · **Price:** Free
**Contact:** email rofiqulislam90.cse@gmail.com · phone/WhatsApp 01730781320
**Privacy policy:** https://bakibondhu.infinityfreeapp.com/privacy.html

## 5. Graphics you must upload (console requires these)

| Asset | Size | Notes |
|---|---|---|
| App icon (hi-res) | **512×512** PNG, 32-bit | The store icon. |
| Feature graphic | **1024×500** PNG/JPG | Banner at the top of the listing. |
| Phone screenshots | 2–8, min 320px, 16:9 or 9:16 | Real screens (Home, customer, sales, subscription…). |

Take screenshots on a real phone or the emulator. For the icon/feature graphic
we can generate simple branded ones from the green "বাকিবন্ধু" logo if you want —
just ask.

## 6. Data safety form (answers to give in the console)

- **Does your app collect or share user data?** Yes (collects; does not share with third parties).
- **Data collected:**
  - *Personal info* → **Name**, **Phone number**, **Address** (optional). Purpose: App functionality, Account management.
  - *Financial info* → the ledger amounts are the shop's own business records → answer honestly as "Other financial info" / App functionality if asked; not payment-card data.
- **Is data encrypted in transit?** Yes (HTTPS).
- **Can users request deletion?** Yes — via the contact in the privacy policy.
- **Used for advertising / shared with third parties / tracking?** No. No ads SDK, no analytics SDK.

## 7. Content rating & audience

- **Content rating:** complete the IARC questionnaire → expected **Everyone / PEGI 3**
  (no violence, no ads, no user-generated public content).
- **Target audience:** 18+ (shop owners). Do **not** mark it as directed to children —
  that avoids the Families policy requirements.
- **Ads:** declare **No ads**.

## 8. Console step-by-step (once the account is ready)

1. **Create app** → name, default language, Free, accept declarations.
2. **App content**: Privacy policy URL, Data safety (§6), Content rating (§7),
   Target audience (§7), Ads (No), Government-app (No), News (No).
3. **Store listing**: paste §4 text, upload §5 graphics.
4. **Production → Create release** → enrol in **Play App Signing** → upload the
   `.aab` (§2) → release notes → review → **roll out to Production** (or start
   with **Internal testing** first — recommended, instant, invite yourself).
5. Submit for review. First review typically takes a few days.

## 9. Publishing an update later

Bump the version in `pubspec.yaml` (e.g. `0.1.31+32`) as usual, rebuild the
`.aab` (§2), and upload it as a new Production release. The versionCode must
increase each time. (You can keep shipping the GitHub APK in parallel; the
in-app updater and the Play listing can coexist.)
