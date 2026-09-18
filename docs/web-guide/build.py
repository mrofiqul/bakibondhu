# -*- coding: utf-8 -*-
"""Build the BakiBondhu web-app user guide (Bangla) from its tracked source.

Source of truth (both tracked in this directory):
  * web_guide.base.html   -- artifact-format: a Google-Fonts <link>, then
                             <title> + <style> + body. No embedded screenshots.
  * screenshots/*.png     -- the 5 phone screenshots, already trimmed.

Running `python build.py` regenerates everything into ./dist/ (git-ignored):
  1. web_guide.artifact.html -- base + embedded screenshots. Re-publish this to
       the Claude artifact.
  2. guide_index.html -- the standalone page (full doctype + head). Deploy it to
       the host at /htdocs/app/guide/index.html; it is also the tracked copy at
       php_backend/app/guide/index.html and the local BakiBondhu_Web_Guide.html.

The embed step is not idempotent, so it always runs from the clean base file.
The 5 screenshots are stored already-trimmed, so the build embeds them as-is
(no image library needed).
"""
import base64
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "web_guide.base.html")
SHOTS = os.path.join(HERE, "screenshots")
DIST = os.path.join(HERE, "dist")

# heading (verbatim, Bangla) -> (screenshot file, caption title, caption sub)
SHOT_MAP = [
    ('<h2><span class="num">০৩</span> হোম স্ক্রিন</h2>', "01-home.png",
     "হোম স্ক্রিন", "মোট পাওনা, আজকের বিক্রি, খোঁজা/সাজানো ও কাস্টমারের তালিকা।"),
    ('<h2><span class="num">০৫</span> বাকি ও পরিশোধ লেখা</h2>', "02-customer.png",
     "কাস্টমারের হিসাব", "এখন কত বাকি, আর নিচে সব লেনদেন তারিখসহ।"),
    ('<h2><span class="num">০৭</span> রিমাইন্ডার পাঠানো</h2>', "03-reminder.png",
     "রিমাইন্ডার", "তৈরি বাংলা বার্তা এডিট করে SMS বা WhatsApp-এ পাঠান।"),
    ('<h2><span class="num">০৮</span> কালেকশন ও প্রতিশ্রুতি</h2>', "04-collections.png",
     "কালেকশন", "কার কাছে কবে কী কথা হলো ও পরিশোধের প্রতিশ্রুতি।"),
    ('<h2><span class="num">০৯</span> বিক্রির হিসাব</h2>', "05-sales.png",
     "বিক্রির হিসাব", "দিন / মাস / তিন মাস / বছর অনুযায়ী মোট বিক্রি।"),
]

FIG_CSS = (
    "\n  /* ---- screenshots ---- */\n"
    "  figure.shot{margin:24px auto 8px;max-width:294px}\n"
    "  figure.shot img{display:block;width:100%;height:auto;border:1px solid var(--border);"
    "border-radius:20px;box-shadow:var(--shadow);background:var(--surface)}\n"
    "  figure.shot figcaption{font-size:13px;color:var(--muted);margin-top:10px;text-align:center}\n"
)


def data_uri(name):
    with open(os.path.join(SHOTS, name), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


def embed_shots(html):
    """Insert each screenshot as a <figure> right after its heading, plus CSS."""
    html = html.replace("</style>", FIG_CSS + "</style>", 1)
    for heading, img, cap_t, cap_s in SHOT_MAP:
        assert heading in html, "missing heading: " + heading
        fig = (heading + '\n      <figure class="shot"><img alt="' + cap_t +
               '" src="' + data_uri(img) + '"><figcaption><b>' + cap_t +
               '</b> — ' + cap_s + "</figcaption></figure>")
        html = html.replace(heading, fig, 1)
    return html


def write(path, text):
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", os.path.relpath(path, HERE), "-", len(text), "bytes")


def main():
    os.makedirs(DIST, exist_ok=True)
    base = io.open(BASE, encoding="utf-8").read()
    embedded = embed_shots(base)   # fonts + title + style + body, with screenshots

    # 1) Artifact source (base already carries the fonts link).
    write(os.path.join(DIST, "web_guide.artifact.html"), embedded)

    # 2) Standalone page (full doctype + head). The base opens with the fonts
    #    <link> lines, then <title>; lift those into a proper <head>.
    fonts = embedded.split("<title>", 1)[0]
    title = re.search(r"<title>(.*?)</title>", embedded, re.S).group(1).strip()
    style = re.search(r"<style>.*?</style>", embedded, re.S).group(0)
    body = embedded.split("</style>", 1)[1].strip()

    standalone = (
        '<!doctype html>\n<html lang="bn">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        + fonts + "<title>" + title + "</title>\n"
        '<style>body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n'
        + style + "\n</head>\n<body>\n" + body + "\n</body>\n</html>\n"
    )
    write(os.path.join(DIST, "guide_index.html"), standalone)

    print("done - outputs in", os.path.relpath(DIST, HERE) + os.sep)


if __name__ == "__main__":
    main()
