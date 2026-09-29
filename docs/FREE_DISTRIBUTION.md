# Distributing BakiBondhu for free (no Play Store fee)

The Google Play Store needs a one-time US$25 fee. These channels cost **nothing**.
Two are already live; the third (F-Droid) is prepared and needs an owner-submitted
merge request. See also [PLAY_STORE.md](PLAY_STORE.md) for the paid route (all the
prep there — signing, `.aab`, privacy policy — still applies whenever you decide to pay).

- **Package name:** `com.bakibondhu.bakibondhu`
- **Source repo:** `mrofiqul/bakibondhu` · **APK releases:** `mrofiqul/bakibondhu-app`
- **Privacy policy:** https://bakibondhu.infinityfreeapp.com/privacy.html

---

## 1. Your website — LIVE ✅ (nothing to do)

`https://bakibondhu.infinityfreeapp.com` already has a **📥 Download the App**
button (always the latest APK from GitHub) and a **🌐 Go to web** button. Shopkeepers
install straight from here. This is the primary channel today.

## 2. GitHub Releases + in-app updater — LIVE ✅ (nothing to do)

Every release publishes `BakiBondhu.apk` to `mrofiqul/bakibondhu-app`, and
`releases/latest/download/BakiBondhu.apk` always resolves to the newest one. The
app's built-in **Settings → Update app** checks this and installs updates. No store
needed for updates.

## 3. F-Droid — free open-source app store (prepared; owner submits)

F-Droid lists free/open-source apps at no cost. BakiBondhu qualifies: MIT-licensed,
no Google Play Services / Firebase / ads / proprietary SDKs. F-Droid **builds from
source** and **auto-extracts the app icon** from the launcher icon, so you don't
upload binaries or graphics — you submit a metadata file and their team builds it.

**Already in the repo:** store text at
`Android_App/fastlane/metadata/android/{en-US,bn-BD}/` (title, short/full
description, changelog) — F-Droid reads these automatically.

**What still needs doing (owner, via GitLab — free account):**

1. Make sure the source repo has a **git tag** for the release you want built
   (e.g. `v0.1.30`) on `mrofiqul/bakibondhu`. *(We currently tag the APK repo; add a
   matching tag on the source repo — `git tag v0.1.30 && git push origin v0.1.30`.)*
2. Fork **https://gitlab.com/fdroid/fdroiddata** (free GitLab account).
3. Add a metadata file `metadata/com.bakibondhu.bakibondhu.yml` — starting point:

   ```yaml
   Categories:
     - Money
   License: MIT
   AuthorName: Rafiq
   SourceCode: https://github.com/mrofiqul/bakibondhu
   IssueTracker: https://github.com/mrofiqul/bakibondhu/issues
   Website: https://bakibondhu.infinityfreeapp.com

   RepoType: git
   Repo: https://github.com/mrofiqul/bakibondhu

   Builds:
     - versionName: 0.1.30
       versionCode: 31
       commit: v0.1.30
       subdir: Android_App/android/app
       sudo: []
       gradle:
         - yes
       flutter: true
       output: build/app/outputs/bundle/release/app-release.aab
       srclibs: []
       prebuild: ''
       # kSyncBaseUrl now DEFAULTS to production, so a plain flutter build
       # (no --dart-define) is already correct — nothing extra needed here.

   AutoUpdateMode: Version v%v
   UpdateCheckMode: Tags
   CurrentVersion: 0.1.30
   CurrentVersionCode: 31
   ```

   > ✅ **Backend URL is handled:** `lib/core/config.dart`'s `kSyncBaseUrl` now
   > defaults to `https://bakibondhu.infinityfreeapp.com`, so F-Droid's plain
   > `flutter build` (no `--dart-define`) ships a working, production-pointing app.

4. Open a **merge request** to fdroiddata. Their maintainers review + build it
   (this can take days to a few weeks). Once merged it appears in F-Droid, and
   future tagged releases update automatically (`UpdateCheckMode: Tags`).

## 4. Other free stores (optional, owner-driven)

Both are free to register (no $25) but need you to create an account and upload the
APK through their console — same `BakiBondhu.apk` we already build:

- **Amazon Appstore** — https://developer.amazon.com (free developer account).
- **Samsung Galaxy Store** — https://seller.samsung.com (free; Samsung devices).

No repo changes are needed for these — just upload the existing APK and paste the
store text from `fastlane/metadata/…` or `PLAY_STORE.md §4`.

---

### Summary

| Channel | Cost | Status |
|---|---|---|
| Website download | Free | **Live** |
| GitHub Releases + in-app updater | Free | **Live** |
| F-Droid | Free | Prepared — needs the config default change + a GitLab MR |
| Amazon Appstore / Samsung Galaxy Store | Free | Optional — upload the APK in their console |
| Google Play | US$25 one-time | Prepped ([PLAY_STORE.md](PLAY_STORE.md)); pay when ready |
