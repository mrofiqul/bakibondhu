# Owner's Manual (source)

The platform **Owner's Manual** — how the platform owner runs everything from
the web admin panel. This directory holds its **source**; the published copies
are generated from it.

## Files

| Path | Role |
| --- | --- |
| `owner_manual.base.html` | **Source of truth.** Artifact-format (`<title>` + `<style>` + body), 16 numbered sections, green palette (Fraunces / IBM Plex / Noto Sans Bengali). No fonts link, no embedded images. |
| `screenshots/*.png` | The 6 real admin-panel screenshots embedded by the build. |
| `build.py` | Regenerates every published output into `dist/`. |
| `dist/` | Build output — **git-ignored**, safe to delete. |

Edit **`owner_manual.base.html`** (and, if the UI changed, replace the PNGs in
`screenshots/`), then run the build. Never hand-edit a file in `dist/`.

## Build

```bash
python build.py
```

Requires only the Python standard library. It writes three files to `dist/`:

1. **`owner_manual.artifact.html`** — base + embedded screenshots + a
   Google-Fonts `<link>`. Re-publish this to the Claude **artifact**.
2. **`BakiBondhu_Owner_Manual.html`** — a standalone single page (full doctype
   + head with fonts) for local viewing or sharing as one file. This is the
   copy kept at the repo root as `BakiBondhu_Owner_Manual.html`.
3. **`manual_index.php`** — the admin-gated page for the host. A PHP session
   gate verifies the Admin username + password against the `admins` table (the
   same credentials as the admin panel) and embeds the manual inline, so there
   is no separately fetchable HTML file to bypass the gate.

The screenshot embed is **not idempotent**, so the build always starts from the
clean `owner_manual.base.html`.

## Deploy

The manual lives in **three** places, all produced by one build:

1. **Artifact** — publish `dist/owner_manual.artifact.html`.
2. **Local file** — copy `dist/BakiBondhu_Owner_Manual.html` to the repo root
   (tracked there for convenience).
3. **Gated web page** — upload `dist/manual_index.php` via FTP to
   `/htdocs/manual/index.php`. Live at `/manual/`, sign in with the Admin
   account.

## Screenshots

The six PNGs are captured from the live admin panel with a headless-Chrome
DevTools screenshot helper (seed a demo shop → screenshot each tab → trim
margins). The heading each screenshot is placed under is defined by `SHOT_MAP`
in `build.py`. To refresh them, recapture into `screenshots/` keeping the same
filenames and re-run the build.
