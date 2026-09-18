# -*- coding: utf-8 -*-
"""Build the BakiBondhu Owner's Manual from its tracked source.

Source of truth (both tracked in this directory):
  * owner_manual.base.html   -- artifact-format: <title> + <style> + body,
                                 no fonts link, no embedded screenshots.
  * screenshots/*.png        -- the 6 admin-panel screenshots.

Running `python build.py` regenerates everything into ./dist/ (git-ignored):
  1. owner_manual.artifact.html -- base + embedded screenshots + a Google-Fonts
       <link> prepended. This is what you re-publish to the Claude artifact.
  2. BakiBondhu_Owner_Manual.html -- a standalone page (full doctype + head with
       fonts) for local viewing / sharing as a single file.
  3. manual_index.php -- the admin-gated page served at /manual/ on the host.
       Upload it via FTP to /htdocs/manual/index.php. It verifies the Admin
       username+password against the `admins` table (same as the panel) and
       embeds the manual so there is no separately fetchable file to bypass it.

The embed step is not idempotent, so it always runs from the clean base file.
"""
import base64
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "owner_manual.base.html")
SHOTS = os.path.join(HERE, "screenshots")
DIST = os.path.join(HERE, "dist")

FONTS = (
    '<link rel="preconnect" href="https://fonts.googleapis.com">'
    '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
    '<link href="https://fonts.googleapis.com/css2?'
    'family=Fraunces:opsz,wght@9..144,500;9..144,600&'
    'family=IBM+Plex+Sans:wght@400;500;600&'
    'family=IBM+Plex+Mono:wght@500&'
    'family=Noto+Sans+Bengali:wght@400;600&display=swap" rel="stylesheet">'
)

# heading (verbatim) -> (screenshot file, alt text, caption HTML)
SHOT_MAP = [
    ('<h2><span class="num">03</span> Signing in to the panel</h2>',
     "06-login.png", "BakiBondhu admin sign-in screen",
     "The admin sign-in box at <b>/admin</b> — enter username <b>Admin</b> and your password."),
    ('<h2><span class="num">04</span> The dashboard (Overview tab)</h2>',
     "01-overview.png", "Admin Overview dashboard with KPI tiles and recent activity",
     "The Overview tab: KPI tiles, the 14-day new-shops chart, and the Recent-activity feed."),
    ('<h2><span class="num">05</span> Managing shops (Shops tab)</h2>',
     "02-shops.png", "Shops tab listing every shop with per-row actions",
     "The Shops tab — one row per shop with its stats and the <b>View · Set expiry · Suspend · Delete</b> actions."),
    ('<h2><span class="num">06</span> Subscriptions &amp; trials</h2>',
     "03-set-expiry.png", "Set-expiry modal for a shop's subscription date",
     "The <b>Set expiry</b> dialog — pick the date the subscription runs through, or make it unlimited."),
    ('<h2><span class="num">09</span> Customers, sales &amp; data cleanup</h2>',
     "04-shop-detail.png", "Shop detail modal: users, customers and balances, and direct sales",
     "The shop <b>View</b> detail — users, every customer with their balance, and the direct-sales section."),
    ('<h2><span class="num">11</span> The audit log</h2>',
     "05-audit.png", "Audit log of admin actions",
     "The Audit log — every admin action (who, what, which shop, when), newest first."),
]

FIG_CSS = (
    "\n  /* ---- screenshots ---- */\n"
    "  figure.shot{margin:22px 0 8px;border:1px solid var(--border);border-radius:var(--radius);"
    "overflow:hidden;background:var(--surface-2);box-shadow:var(--shadow)}\n"
    "  figure.shot img{display:block;width:100%;height:auto}\n"
    "  figure.shot figcaption{font-size:12.5px;color:var(--muted);padding:9px 14px;"
    "border-top:1px solid var(--border);background:var(--surface)}\n"
)

# a thin "protected" bar shown at the very top of the host-served manual
BANNER = (
    '<div style="background:#0d5a34;color:#eaf3ec;font:13px/1.4 system-ui,sans-serif;'
    'padding:8px 16px;display:flex;justify-content:space-between;align-items:center;gap:12px">'
    '<span>&#128274; Protected &middot; admin only</span>'
    '<a href="?logout=1" style="color:#fff;font-weight:600;text-decoration:none;'
    'border:1px solid rgba(255,255,255,.5);border-radius:6px;padding:3px 10px">Log out</a></div>'
)

LOGIN_PAGE = """<!doctype html>
<html lang="bn"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Manual &middot; Admin sign in</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f3f4ef;
    color:#1a201b;font-family:"Segoe UI","Noto Sans Bengali",system-ui,sans-serif;padding:20px}
  .box{background:#fff;border:1px solid #e1e6dc;border-radius:16px;box-shadow:0 10px 30px rgba(20,40,25,.08);
    padding:28px;width:min(360px,94vw)}
  h1{margin:0 0 2px;font-size:20px;color:#0d5a34}
  p.s{margin:0 0 18px;color:#5c665e;font-size:13.5px}
  label{display:block;font-size:13px;color:#5c665e;margin:12px 0 5px}
  input{width:100%;padding:11px 12px;border:1px solid #cfd8cc;border-radius:9px;font-size:15px}
  button{width:100%;margin-top:18px;background:#167c48;color:#fff;border:0;border-radius:999px;
    padding:12px;font-size:15px;font-weight:700;cursor:pointer}
  button:hover{background:#0d5a34}
  .err{color:#b3261e;font-size:13px;margin-top:12px;min-height:16px}
  .lock{font-size:26px}
</style></head>
<body>
  <form class="box" method="post" autocomplete="off">
    <div class="lock">&#128274;</div>
    <h1>Owner's Manual</h1>
    <p class="s">Sign in with your <b>Admin</b> account to read the manual.</p>
    <label>Username</label>
    <input name="u" autocomplete="username" autofocus>
    <label>Password</label>
    <input name="p" type="password" autocomplete="current-password">
    <button type="submit">Sign in</button>
    <div class="err">__ERR__</div>
  </form>
</body></html>"""

PHP_GATE = r"""<?php
// Admin-only gate for the BakiBondhu Owner's Manual. Access requires the same
// Admin username + password as the admin panel (checked against `admins`).
session_start();
require_once __DIR__ . '/../lib.php';
$cfg = require __DIR__ . '/../config.php';

if (isset($_GET['logout'])) { $_SESSION = []; session_destroy(); header('Location: ./'); exit; }

$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && empty($_SESSION['manual_ok'])) {
    $u = trim((string)($_POST['u'] ?? ''));
    $p = (string)($_POST['p'] ?? '');
    try {
        $db = bb_db($cfg);
        $st = $db->prepare('SELECT password_hash FROM admins WHERE username = ? LIMIT 1');
        $st->execute([$u]);
        $h = $st->fetchColumn();
        if ($h && password_verify($p, $h)) {
            session_regenerate_id(true);
            $_SESSION['manual_ok'] = true;
            header('Location: ./'); exit;
        }
    } catch (Throwable $e) { /* fall through to error */ }
    $err = 'ভুল ইউজারনেম বা পাসওয়ার্ড';
}

"""


def data_uri(name):
    with open(os.path.join(SHOTS, name), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


def embed_shots(html):
    """Insert each screenshot as a <figure> right after its heading, plus CSS."""
    html = html.replace("</style>", FIG_CSS + "</style>", 1)
    for heading, img, alt, cap in SHOT_MAP:
        assert heading in html, "missing heading: " + heading
        fig = (heading + '\n      <figure class="shot"><img alt="' + alt +
               '" src="' + data_uri(img) + '"><figcaption>' + cap + "</figcaption></figure>")
        html = html.replace(heading, fig, 1)
    return html


def write(path, text):
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", os.path.relpath(path, HERE), "-", len(text), "bytes")


def main():
    os.makedirs(DIST, exist_ok=True)
    base = io.open(BASE, encoding="utf-8").read()
    embedded = embed_shots(base)   # artifact-format body with screenshots

    title = re.search(r"<title>(.*?)</title>", embedded, re.S).group(1).strip()
    style = re.search(r"<style>.*?</style>", embedded, re.S).group(0)
    body = embedded.split("</style>", 1)[1].strip()

    # 1) Artifact source (fonts link prepended so it renders in its faces).
    write(os.path.join(DIST, "owner_manual.artifact.html"), FONTS + "\n" + embedded)

    # 2) Standalone local file (full doctype + head).
    standalone = (
        '<!doctype html>\n<html lang="en">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        + FONTS + "\n<title>" + title + "</title>\n"
        '<style>body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n'
        + style + "\n</head>\n<body>\n" + body + "\n</body>\n</html>\n"
    )
    write(os.path.join(DIST, "BakiBondhu_Owner_Manual.html"), standalone)

    # 3) Admin-gated PHP page for /manual/.
    manual_page = (
        '<!doctype html>\n<html lang="en">\n<head>\n'
        '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<meta name="robots" content="noindex, nofollow">\n'
        + FONTS + "\n<title>" + title + "</title>\n"
        '<style>body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n'
        + style + "\n</head>\n<body>\n" + BANNER + "\n" + body + "\n</body>\n</html>\n"
    )
    php = PHP_GATE
    php += "$LOGIN_HTML = <<<'BB_LOGIN'\n" + LOGIN_PAGE + "\nBB_LOGIN;\n\n"
    php += "$MANUAL_HTML = <<<'BB_MANUAL'\n" + manual_page + "\nBB_MANUAL;\n\n"
    php += (
        "header('Content-Type: text/html; charset=utf-8');\n"
        "if (empty($_SESSION['manual_ok'])) {\n"
        "    echo str_replace('__ERR__', htmlspecialchars($err, ENT_QUOTES, 'UTF-8'), $LOGIN_HTML);\n"
        "    exit;\n"
        "}\n"
        "echo $MANUAL_HTML;\n"
    )
    write(os.path.join(DIST, "manual_index.php"), php)

    print("done - outputs in", os.path.relpath(DIST, HERE) + os.sep)


if __name__ == "__main__":
    main()
