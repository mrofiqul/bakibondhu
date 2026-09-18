# Documentation

All BakiBondhu documentation lives here — the end-user and developer manuals,
plus the **source** for the two HTML guides that are published to the web and as
Claude artifacts.

## Contents

| Path | What it is | Audience |
| --- | --- | --- |
| [`USER_MANUAL_BN.md`](USER_MANUAL_BN.md) | Shopkeeper user guide (Bangla) | App users |
| [`USER_MANUAL_EN.md`](USER_MANUAL_EN.md) | Shopkeeper user guide (English) | App users |
| [`DEVELOPER_MANUAL.md`](DEVELOPER_MANUAL.md) | Architecture, backend, build & release | Developers |
| [`owner-manual/`](owner-manual/) | **Source** for the platform Owner's Manual (HTML) | Platform owner |
| [`web-guide/`](web-guide/) | **Source** for the web-app user guide (HTML) | Web-app users |

The `.md` files are read directly. The two folders are **build sources** — you
edit the source and run a script to regenerate the published pages.

## HTML manual sources

Both folders follow the same layout and workflow:

```
docs/<name>/
  *.base.html        # source of truth (artifact-format: <title> + <style> + body)
  screenshots/*.png  # embedded screenshots
  build.py           # regenerates every published copy into dist/ (git-ignored)
  README.md          # per-manual build + deploy details
```

Edit the `*.base.html` (and swap screenshots if the UI changed), then:

```bash
python docs/owner-manual/build.py   # or docs/web-guide/build.py
```

Never hand-edit anything in a `dist/` folder — it is generated.

### [`owner-manual/`](owner-manual/) — platform Owner's Manual

How the platform owner runs everything from the web admin panel. Build outputs:

1. `owner_manual.artifact.html` — publish to the Claude artifact.
2. `BakiBondhu_Owner_Manual.html` — standalone single file (also kept at the
   repo root).
3. `manual_index.php` — the admin-gated page at `/manual/` (upload to
   `/htdocs/manual/index.php`; login uses the Admin account).

See [`owner-manual/README.md`](owner-manual/README.md).

### [`web-guide/`](web-guide/) — web-app user guide

The Bangla shopkeeper guide for the web app at `/app`. Build outputs:

1. `web_guide.artifact.html` — publish to the Claude artifact.
2. `guide_index.html` — the standalone page served at `/app/guide/`; also the
   tracked copy at `php_backend/app/guide/index.html` and the local
   `BakiBondhu_Web_Guide.html`.

See [`web-guide/README.md`](web-guide/README.md).

## Notes

- All HTML is stored with LF line endings (pinned by the repo-root
  `.gitattributes`), so a fresh build matches the checkout byte-for-byte.
- Screenshots are stored already-trimmed; the builds embed them as inline
  base64 and need only the Python standard library.
