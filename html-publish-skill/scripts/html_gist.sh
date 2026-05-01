#!/usr/bin/env bash
# html_gist.sh — Plan B: Publish HTML via Litterbox (litter.catbox.moe)
#
# Litterbox is a temporary file hosting service by the catbox.moe community.
# - Zero auth required — pure curl upload
# - Files served as text/html (renders directly in browser, no download prompt)
# - Retention: up to 72 hours (suitable for sharing & demos)
# - No size limit for typical HTML files
# - Fallback API: https://litterbox.catbox.moe
#
# Usage:
#   html_gist.sh <html-file> [--ttl 1h|12h|24h|72h]

set -euo pipefail

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

# ── parse args ────────────────────────────────────────────────────────────────
HTML_FILE=""
TTL="72h"   # 1h | 12h | 24h | 72h

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ttl)   TTL="${2:-72h}"; shift 2 ;;
    --desc)  shift 2 ;;  # ignored, kept for interface compat
    --help|-h)
      echo "Usage: html_gist.sh <html-file> [--ttl 1h|12h|24h|72h]"
      echo "Publishes HTML to Litterbox (litter.catbox.moe) — rendered as text/html."
      exit 0 ;;
    -*)  die "Unknown option: $1" ;;
    *)   HTML_FILE="$1"; shift ;;
  esac
done

[[ -z "$HTML_FILE" ]] && die "HTML file argument is required"
[[ -f "$HTML_FILE" ]] || die "File not found: $HTML_FILE"

FILE_SIZE=$(wc -c < "$HTML_FILE" | tr -d ' ')
info "Uploading to Litterbox (${FILE_SIZE} bytes, TTL=${TTL})..."

# ── upload ────────────────────────────────────────────────────────────────────
RESPONSE=$(curl -sk \
  -F "reqtype=fileupload" \
  -F "time=${TTL}" \
  -F "fileToUpload=@${HTML_FILE}" \
  https://litterbox.catbox.moe/resources/internals/api.php 2>&1) || {
    die "Upload to Litterbox failed. Check network."
  }

# Response is the URL on a single line
URL=$(echo "$RESPONSE" | grep -E '^https?://' | head -1)
[[ -z "$URL" ]] && die "Unexpected response from Litterbox: $RESPONSE"

# ── verify ────────────────────────────────────────────────────────────────────
info "Verifying URL..."
HTTP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null || echo "000")
CTYPE=$(curl -sk -o /dev/null -w "%{content_type}" --max-time 10 "$URL" 2>/dev/null || echo "")

echo ""
if [[ "$HTTP" == "200" ]]; then
  ok "Published on Litterbox!"
else
  ok "Uploaded (HTTP ${HTTP})"
fi

echo "  URL   : $URL"
echo "  Type  : ${CTYPE:-unknown}"
echo "  TTL   : ${TTL} from now"
echo "  Note  : Litterbox by catbox.moe community — temp hosting, no auth needed"
echo "$URL"   # final parseable line
