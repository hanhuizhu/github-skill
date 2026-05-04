#!/usr/bin/env bash
# upload-static.sh — Upload a static asset to a GitHub repo via Contents API
#
# Usage:
#   upload-static.sh --file <path> --repo <owner/repo> [options]
#
# Examples:
#   upload-static.sh --file ./screenshot.png --repo hanhuizhu/image-uploads
#   upload-static.sh --file ./video.mp4 --repo hanhuizhu/assets --branch gh-pages --path videos/

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

# ── parse args ────────────────────────────────────────────────────────────────
FILE=""
REPO=""
BRANCH="main"
UPLOAD_PATH="uploads/"
COMMIT_MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)   FILE="${2:-}";    shift 2 ;;
    --repo)   REPO="${2:-}";    shift 2 ;;
    --branch) BRANCH="${2:-}";  shift 2 ;;
    --path)   UPLOAD_PATH="${2:-}"; shift 2 ;;
    --message|-m) COMMIT_MSG="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: upload-static.sh --file <path> --repo <owner/repo> [options]"
      echo ""
      echo "Required:"
      echo "  --file <path>        File to upload"
      echo "  --repo <owner/repo>  GitHub repository (e.g. hanhuizhu/image-uploads)"
      echo ""
      echo "Options:"
      echo "  --branch <name>      Target branch (default: main)"
      echo "  --path <prefix>      Upload path prefix (default: uploads/)"
      echo "  --message <msg>      Commit message (auto-generated if omitted)"
      exit 0 ;;
    *) die "Unknown option: $1 (use --help for usage)" ;;
  esac
done

# ── validate ──────────────────────────────────────────────────────────────────
[[ -z "$FILE" ]] && die "--file is required"
[[ -z "$REPO" ]] && die "--repo is required (e.g. hanhuizhu/image-uploads)"
[[ ! -f "$FILE" ]] && die "File not found: $FILE"

# ── load token ────────────────────────────────────────────────────────────────
TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(cat "$TOKEN_FILE")"
  TOKEN="${TOKEN%$'\n'}"
fi
[[ -z "$TOKEN" ]] && die "No GitHub token found. Set GITHUB_TOKEN or create ~/.github_skill_token"

# ── build target path ─────────────────────────────────────────────────────────
BASENAME=$(basename "$FILE")
EXT="${BASENAME##*.}"
TIMESTAMP=$(date +%s)
CLEAN_NAME="${TIMESTAMP}.${EXT}"

# Normalize upload path: ensure trailing slash
UPLOAD_PATH="${UPLOAD_PATH%/}/"

TARGET_PATH="${UPLOAD_PATH}${CLEAN_NAME}"

# ── generate commit message ───────────────────────────────────────────────────
if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG="Upload: ${CLEAN_NAME}"
fi

# ── base64 encode ─────────────────────────────────────────────────────────────
info "Reading: $FILE"
if command -v openssl &>/dev/null; then
  CONTENT=$(openssl base64 -in "$FILE" | tr -d '\n')
elif command -v base64 &>/dev/null; then
  CONTENT=$(base64 -i "$FILE" 2>/dev/null || base64 < "$FILE" | tr -d '\n')
else
  die "No base64 encoder found (need openssl or base64)"
fi

# ── upload via GitHub Contents API ────────────────────────────────────────────
info "Uploading to ${REPO}/${BRANCH}/${TARGET_PATH} ..."

RESP=$(curl -s -w "\n%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.github+json" \
  "${API}/repos/${REPO}/contents/${TARGET_PATH}" \
  -d "$(cat <<-EOF
{
  "message": "$COMMIT_MSG",
  "content": "$CONTENT",
  "branch": "$BRANCH"
}
EOF
)")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${TARGET_PATH}"
  echo ""
  ok "Upload successful!"
  echo "  URL : $RAW_URL"
  echo ""
  # Try to copy to clipboard
  if command -v pbcopy &>/dev/null; then
    echo "$RAW_URL" | pbcopy && echo "  (URL copied to clipboard)"
  fi
else
  ERR_MSG=$(echo "$BODY" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
  die "Upload failed (HTTP $HTTP_CODE): ${ERR_MSG:-unknown error}"
fi
