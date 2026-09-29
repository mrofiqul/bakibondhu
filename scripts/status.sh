#!/usr/bin/env bash
# BakiBondhu — quick status check.
#   Run from anywhere:  bash scripts/status.sh
# Shows: latest published version, download totals (GitHub), the server's
# advertised version, and /health. Needs: gh (logged in), curl, openssl, xxd.
# For the true active-user / signup count, open the Admin panel (printed below).
set -uo pipefail

REPO="mrofiqul/bakibondhu-app"
HOST="https://bakibondhu.infinityfreeapp.com"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

hr(){ printf '%s\n' "------------------------------------------------------------"; }

echo "BakiBondhu status  ·  $(date '+%Y-%m-%d %H:%M')"
hr

# ---- Latest release + downloads (GitHub; no anti-bot) ----
echo "Latest release (GitHub):"
if command -v gh >/dev/null 2>&1; then
  gh api "repos/$REPO/releases/latest" \
    --jq '"  " + .tag_name + "   \"" + .name + "\"   published " + (.published_at|split("T")[0])' 2>/dev/null \
    || echo "  (could not read — is gh logged in?  run: gh auth status)"
  echo
  echo "Downloads per release:"
  gh api "repos/$REPO/releases" \
    --jq '.[] | "  " + .tag_name + ":  " + ([.assets[].download_count]|add|tostring)' 2>/dev/null | head -20
  TOTAL=$(gh api "repos/$REPO/releases" --jq '[.[].assets[].download_count]|add' 2>/dev/null)
  echo "  ----------------------"
  echo "  TOTAL downloads:  ${TOTAL:-?}"
else
  echo "  (gh CLI not found — install it or check the Releases page in a browser)"
fi
hr

# ---- Solve the InfinityFree anti-bot cookie (needed for the host endpoints) ----
# The host serves a JS challenge on the first hit; solve it so curl can pass.
solve_cookie(){
  local html a b c
  html=$(curl -s --max-time 20 -A "$UA" "$HOST/" 2>/dev/null)
  grep -q "toNumbers" <<<"$html" || { echo ""; return; }        # no challenge -> no cookie
  # three 32-hex values in order: ciphertext, key, iv
  local hx=(); while IFS= read -r line; do hx+=("$line"); done < <(grep -oE '[0-9a-f]{32}' <<<"$html")
  a=${hx[0]:-}; b=${hx[1]:-}; c=${hx[2]:-}
  [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] || { echo ""; return; }
  printf '%s' "$a" | xxd -r -p 2>/dev/null | openssl enc -aes-128-cbc -d -K "$b" -iv "$c" -nopad 2>/dev/null | xxd -p 2>/dev/null | tr -d '\n'
}
CK=$(solve_cookie)
fetch(){ curl -s --max-time 25 -A "$UA" ${CK:+-b "__test=$CK"} "$1" 2>/dev/null; }

# ---- Server-advertised version ----
echo "Server version endpoint  ($HOST/api/v1/app/version):"
VER=$(fetch "$HOST/api/v1/app/version")
if command -v jq >/dev/null 2>&1 && jq -e . >/dev/null 2>&1 <<<"$VER"; then
  jq -r '"  android " + .android.version + "  (build " + (.android.build|tostring) + ")   /   web " + (.web.build|tostring)' <<<"$VER"
elif grep -q '"version"' <<<"$VER"; then
  echo "  $(tr -d '\n' <<<"$VER" | cut -c1-200)"
else
  echo "  (couldn't reach it from here — open the URL in a browser to check)"
fi
hr

# ---- Health ----
echo "Health  ($HOST/health):"
H=$(fetch "$HOST/health")
if [ -n "$H" ] && ! grep -qiE "<html|<!doctype" <<<"$H"; then
  echo "  OK  ->  $(tr -d '\n' <<<"$H" | cut -c1-160)"
else
  echo "  (no clean response from here — open $HOST/health in a browser)"
fi
hr

echo "Active users / new signups:  open the Admin panel (login required):"
echo "  $HOST/admin"
