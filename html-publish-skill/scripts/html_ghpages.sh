#!/usr/bin/env bash
# html_ghpages.sh — Plan A: Publish a single HTML file via GitHub Pages
#
# Flow:
#   1. Create a new public GitHub repo (or reuse --repo if given)
#   2. Push the HTML as index.html on main branch
#   3. Enable GitHub Pages via API
#   4. Poll until deployment ready (up to 90 s)
#   5. Print the live URL
#
# Usage:
#   html_ghpages.sh <html-file> [--repo <name>] [--keep]
#
# Options:
#   --repo <name>   Repo name to create/reuse (default: html-pub-<epoch>)
#   --keep          Don't delete the repo on failure (useful for debugging)

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

die()    { echo "[ERROR] $*" >&2; exit 1; }
info()   { echo "[INFO]  $*"; }
ok()     { echo "[OK]    $*"; }
warn()   { echo "[WARN]  $*" >&2; }

# ── load token ────────────────────────────────────────────────────────────────
load_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then
    t="$(cat "$TOKEN_FILE")"; t="${t%$'\n'}"
  fi
  [[ -z "$t" ]] && die "No GitHub token. Set GITHUB_TOKEN or run: gh_auth.sh --token <TOKEN>"
  echo "$t"
}

# ── parse args ────────────────────────────────────────────────────────────────
HTML_FILE=""
REPO_NAME=""
KEEP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)  REPO_NAME="${2:-}"; shift 2 ;;
    --keep)  KEEP=true; shift ;;
    --help|-h)
      echo "Usage: html_ghpages.sh <html-file> [--repo <name>] [--keep]"
      exit 0 ;;
    -*)  die "Unknown option: $1" ;;
    *)   HTML_FILE="$1"; shift ;;
  esac
done

[[ -z "$HTML_FILE" ]] && die "HTML file argument is required"
[[ -f "$HTML_FILE" ]] || die "File not found: $HTML_FILE"

TOKEN=$(load_token)

# ── get owner ─────────────────────────────────────────────────────────────────
OWNER=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "${API}/user" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
[[ -z "$OWNER" ]] && die "Cannot determine GitHub username — check token."

# ── repo name ─────────────────────────────────────────────────────────────────
[[ -z "$REPO_NAME" ]] && REPO_NAME="html-pub-$(date +%s)"
REPO_NAME="${REPO_NAME//[^a-zA-Z0-9._-]/-}"   # sanitize

# ── create repo ───────────────────────────────────────────────────────────────
info "Creating repo: ${OWNER}/${REPO_NAME}"
HTTP=$(curl -s -o /tmp/ghp_create.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"auto_init\":false}" \
  "${API}/user/repos")

RESP=$(cat /tmp/ghp_create.json); rm -f /tmp/ghp_create.json

case "$HTTP" in
  201) ;;
  422)
    # Repo already exists — reuse it
    warn "Repo already exists, reusing: ${OWNER}/${REPO_NAME}"
    ;;
  *)
    die "Failed to create repo (HTTP ${HTTP}): $RESP"
    ;;
esac

REPO_DIR=$(mktemp -d)
trap '[[ "$KEEP" == "false" ]] && rm -rf "$REPO_DIR"' EXIT

# ── init local repo and push index.html ──────────────────────────────────────
info "Preparing index.html..."
cp "$HTML_FILE" "$REPO_DIR/index.html"

# Simple CNAME / 404 pages not needed — just index.html
cd "$REPO_DIR"
git init -q
git config user.email "html-publish@local"
git config user.name "html-publish"

git add index.html
git commit -q -m "Publish $(basename "$HTML_FILE")"

REMOTE_URL="https://${TOKEN}@github.com/${OWNER}/${REPO_NAME}.git"
git remote add origin "$REMOTE_URL"

info "Pushing to GitHub..."
git push -q --force origin main 2>/dev/null || git push -q --force origin HEAD:main

cd - > /dev/null

# ── enable GitHub Pages ───────────────────────────────────────────────────────
info "Enabling GitHub Pages..."
HTTP=$(curl -s -o /tmp/ghp_pages.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  -d '{"source":{"branch":"main","path":"/"}}' \
  "${API}/repos/${OWNER}/${REPO_NAME}/pages")

PAGES_RESP=$(cat /tmp/ghp_pages.json); rm -f /tmp/ghp_pages.json

PAGES_URL=""
if [[ "$HTTP" == "201" || "$HTTP" == "409" ]]; then
  # 409 = Pages already enabled — fetch existing URL
  if [[ "$HTTP" == "409" ]]; then
    PAGES_RESP=$(curl -s \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "${API}/repos/${OWNER}/${REPO_NAME}/pages")
  fi
  PAGES_URL=$(echo "$PAGES_RESP" | grep -o '"html_url":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

[[ -z "$PAGES_URL" ]] && PAGES_URL="https://${OWNER}.github.io/${REPO_NAME}/"

# ── poll until live (up to 90 s) ──────────────────────────────────────────────
info "Waiting for GitHub Pages to deploy: $PAGES_URL"
ELAPSED=0
INTERVAL=5
while [[ $ELAPSED -lt 90 ]]; do
  HTTP_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$PAGES_URL" 2>/dev/null || echo "000")
  if [[ "$HTTP_CHECK" == "200" ]]; then
    echo ""
    ok "GitHub Pages is live!"
    echo "  URL  : $PAGES_URL"
    echo "  Repo : https://github.com/${OWNER}/${REPO_NAME}"
    echo "$PAGES_URL"   # final line = parseable URL
    exit 0
  fi
  printf "  [%ds] HTTP %s — waiting...\r" "$ELAPSED" "$HTTP_CHECK"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Not yet live but likely deploying
warn "Pages not yet live after 90s (GitHub may still be deploying)"
echo ""
echo "  Expected URL: $PAGES_URL"
echo "  Check again in ~1 minute."
echo "$PAGES_URL"
