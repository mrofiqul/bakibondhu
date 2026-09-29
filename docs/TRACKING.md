# Tracking BakiBondhu — how to check status & know how it's doing

A single place for "is it live?", "what version is out?", "how many people use
it?", and "is the server healthy?". Grouped by what you want to know.

- **Live site:** https://bakibondhu.infinityfreeapp.com
- **Web app:** https://bakibondhu.infinityfreeapp.com/app
- **Admin panel:** https://bakibondhu.infinityfreeapp.com/admin *(admin login)*
- **Source repo:** https://github.com/mrofiqul/bakibondhu
- **APK releases:** https://github.com/mrofiqul/bakibondhu-app/releases
- **Package name:** `com.bakibondhu.bakibondhu`

---

## 1. How many people use my app? (the real number)

Every account syncs to your server, so the **Admin panel is the source of truth**.

- Open **https://bakibondhu.infinityfreeapp.com/admin** and log in.
- The dashboard shows **total shops, new signups, outstanding credit across all
  shops, and recent activity**. From the **Shops** list you can see each shop, its
  owner, mobile, and subscription expiry, and suspend / delete / reset-password.
- This counts **registered accounts** — the true active user base (since v0.1.20 an
  account is required to use the app).

**Deeper look (optional):** phpMyAdmin from the InfinityFree control panel → database
`if0_42877652_bakibondhu` → **Browse** the `businesses` and `users` tables (e.g.
count rows, sort by `created_at` to see signups over time, `country` to see where
owners are).

## 2. Is the app live and which version is the latest?

- **One quick check** — the version endpoint returns the current numbers as JSON:
  https://bakibondhu.infinityfreeapp.com/api/v1/app/version
  → shows `android.version` / `android.build` and `web.build`. This is what installed
  apps compare against for the in-app "Update available" prompt.
- **Landing page** shows the current version in the download caption.
- **Latest APK** always resolves here (never goes stale):
  https://github.com/mrofiqul/bakibondhu-app/releases/latest/download/BakiBondhu.apk

## 3. How many downloads / installs?

- **GitHub Releases** shows a **download count per release asset**. On the releases
  page each `BakiBondhu.apk` lists how many times it was downloaded. Quick CLI:
  ```bash
  gh api repos/mrofiqul/bakibondhu-app/releases --jq '.[] | {tag:.tag_name, downloads:([.assets[].download_count]|add)}'
  ```
  *(Downloads ≈ installs from the website/GitHub; it's a proxy, not exact installs.)*
- The **Admin panel signup count** (§1) is the better "who's actually using it" number,
  because it counts people who registered and synced.

## 4. Is the server healthy?

- **Health check:** https://bakibondhu.infinityfreeapp.com/health → should return a
  small OK/JSON response. If it returns the landing page's HTML instead, the API
  router was overwritten (see the deploy-paths note in the developer docs).
- **Hosting status / uptime:** the InfinityFree client area (login at
  infinityfree.com) shows account status, disk/bandwidth usage, and any suspension.
  *(Free hosting can pause on very high traffic or daily-hit limits.)*
- **Database:** phpMyAdmin (InfinityFree control panel) — Browse tables, run queries,
  check size.

## 5. F-Droid listing status (the free store)

Once you've opened the merge request (see FREE_DISTRIBUTION.md):

- **Your merge request** on https://gitlab.com/fdroid/fdroiddata — the MR page shows
  review comments and a **CI pipeline** (lint + a test build). Green pipeline + a
  maintainer approval → it gets merged.
- **Build status after merge:** https://monitor.f-droid.org (search the package) and
  the build logs show whether each version built successfully.
- **Public app page (once published):**
  https://f-droid.org/packages/com.bakibondhu.bakibondhu/
  — this is where users find it; it also shows the versions F-Droid has built.
- New releases: **tag the source repo** (`git tag v0.1.x && git push --tags`) and
  F-Droid auto-detects it (UpdateCheckMode: Tags) — no new MR needed.

## 6. Google Play status (only if/when you pay the $25)

In the **Play Console** (https://play.google.com/console):

- **Dashboard** — installs, uninstalls, ratings, crashes over time.
- **Publishing overview / Releases** — review status of each submission ("In review",
  "Live", "Rejected" with the reason).
- **Statistics** — active devices, countries, Android versions.
- **Ratings & reviews** — reply to users.
- **Data safety / Policy status** — any compliance flags to fix.

## 7. Amazon / Samsung (if you upload there)

Each has its own console dashboard (installs, reviews, review status) after you upload
the APK — Amazon: developer.amazon.com, Samsung: seller.samsung.com.

---

## One-command check

Run the status script for latest version, download totals, server version, and
`/health` in one go (needs `gh` logged in, plus `curl`/`openssl`/`xxd`):

```bash
bash scripts/status.sh
```

*(The active-user / signup count still comes from the Admin panel — it needs a login.)*
There's also an HTML version of this guide at `docs/tracking.html` (open it in a browser).

## Quick weekly routine

1. **Admin panel** → new signups + total shops (are people joining?).
2. **`/health`** → server up? · InfinityFree client area → account not suspended?
3. **GitHub releases** → download counts trending?
4. If on F-Droid/Play → check the store dashboard for reviews / crashes / review status.
5. Make sure the **latest release** matches what `/api/v1/app/version` advertises.

> Tip: keep an eye on the InfinityFree **daily hits / bandwidth** limits as usage
> grows — that's the most likely thing to interrupt the free backend. If you hit those
> limits often, that's the signal to move to paid hosting (see the hosting note in the
> project status).
