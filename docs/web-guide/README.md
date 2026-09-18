# Web-app user guide (source)

The Bangla **shopkeeper web-app guide** — how to use the web app at `/app`.
This directory holds its **source**; the published copies are generated from it.

## Files

| Path | Role |
| --- | --- |
| `web_guide.base.html` | **Source of truth.** Artifact-format: a Google-Fonts `<link>`, then `<title>` + `<style>` + body. 13 sections, Baloo Da 2 + Noto Sans Bengali, green theme, light/dark, sticky TOC. No embedded images. |
| `screenshots/*.png` | The 5 phone screenshots (home / customer / reminder / collections / sales), already trimmed. |
| `build.py` | Regenerates every published output into `dist/`. |
| `dist/` | Build output — **git-ignored**, safe to delete. |

Edit **`web_guide.base.html`** (and, if the UI changed, replace the PNGs in
`screenshots/`), then run the build. Never hand-edit a file in `dist/`.

## Build

```bash
python build.py
```

Requires only the Python standard library (the screenshots are stored
already-trimmed, so no image library is needed). It writes two files to `dist/`:

1. **`web_guide.artifact.html`** — base + embedded screenshots. Re-publish this
   to the Claude **artifact**.
2. **`guide_index.html`** — the standalone page (full doctype + head). This is
   the content served at `/app/guide/` and kept at `php_backend/app/guide/index.html`
   (and as the local `BakiBondhu_Web_Guide.html`).

The screenshot embed is **not idempotent**, so the build always starts from the
clean `web_guide.base.html`.

## Deploy

One build produces every copy:

1. **Artifact** — publish `dist/web_guide.artifact.html`.
2. **Hosted page** — copy `dist/guide_index.html` to `php_backend/app/guide/index.html`
   and upload it via FTP to `/htdocs/app/guide/index.html`. Live at `/app/guide/`.
   The web app's Settings has a "📘 সাহায্য / Help" row linking to it.
3. **Local file** — optionally copy `dist/guide_index.html` to the repo root as
   `BakiBondhu_Web_Guide.html` for a directly-openable single file.

`build.py`'s standalone output is content-identical to the currently deployed
`php_backend/app/guide/index.html` (the deployed copy just uses CRLF line
endings).

## Screenshots

The five PNGs are captured from the live web app with a headless-Chrome
DevTools helper, emulating a 390×810 phone and driving the SPA, then trimmed of
uniform margins. The heading each screenshot is placed under is defined by
`SHOT_MAP` in `build.py`. To refresh them, recapture (already trimmed) into
`screenshots/` keeping the same filenames and re-run the build.
