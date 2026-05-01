#!/usr/bin/env bash
# gh_create.sh — Create a new GitHub repository via REST API
#
# Usage:
#   gh_create.sh --name <repo-name> [options]
#
# Options:
#   --name    <name>    Repository name (required)
#   --desc    <text>    Description
#   --private           Make the repository private (default: public)
#   --no-init           Skip auto-initializing with a README
#   --org     <org>     Create under an organization instead of your account

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

load_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then t="$(cat "$TOKEN_FILE")"
    t="${t%$'\n'}"; fi
  [[ -z "$t" ]] && die "No GitHub token found. Run: gh_auth.sh --token <TOKEN>"
  echo "$t"
}

# ── parse args ────────────────────────────────────────────────────────────────
REPO_NAME=""
REPO_DESC=""
PRIVATE=false
AUTO_INIT=true
ORG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)     REPO_NAME="${2:-}";  shift 2 ;;
    --desc)     REPO_DESC="${2:-}";  shift 2 ;;
    --private)  PRIVATE=true;        shift ;;
    --no-init)  AUTO_INIT=false;     shift ;;
    --org)      ORG="${2:-}";        shift 2 ;;
    --help|-h)
      echo "Usage: gh_create.sh --name <name> [--desc <desc>] [--private] [--no-init] [--org <org>]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -z "$REPO_NAME" ]] && die "--name is required"

# Validate name (GitHub rules)
if ! echo "$REPO_NAME" | grep -qE '^[a-zA-Z0-9._-]+$'; then
  die "Invalid repo name '$REPO_NAME'. Use only letters, numbers, ., -, _"
fi

TOKEN=$(load_token)

# ── determine endpoint ────────────────────────────────────────────────────────
if [[ -n "$ORG" ]]; then
  ENDPOINT="${API}/orgs/${ORG}/repos"
  OWNER="$ORG"
else
  ENDPOINT="${API}/user/repos"
  OWNER=$(bash "$(dirname "$0")/gh_auth.sh" --show-user 2>/dev/null || \
          curl -sf -H "Authorization: Bearer $TOKEN" "${API}/user" | \
          grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

# ── build JSON payload ────────────────────────────────────────────────────────
PAYLOAD=$(cat <<EOF
{
  "name": "$REPO_NAME",
  "description": "$REPO_DESC",
  "private": $PRIVATE,
  "auto_init": $AUTO_INIT
}
EOF
)

info "Creating $([[ "$PRIVATE" == "true" ]] && echo "private" || echo "public") repository: ${OWNER}/${REPO_NAME}"
[[ -n "$REPO_DESC" ]] && info "Description: $REPO_DESC"

# ── call API ──────────────────────────────────────────────────────────────────
HTTP_CODE=$(curl -s -o /tmp/gh_create_resp.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$ENDPOINT")

RESP=$(cat /tmp/gh_create_resp.json)
rm -f /tmp/gh_create_resp.json

# ── handle response ───────────────────────────────────────────────────────────
case "$HTTP_CODE" in
  201)
    HTML_URL=$(echo "$RESP" | grep -o '"html_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    CLONE_URL=$(echo "$RESP" | grep -o '"clone_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    SSH_URL=$(echo "$RESP"   | grep -o '"ssh_url":"[^"]*"'   | head -1 | cut -d'"' -f4)
    DEFAULT_BRANCH=$(echo "$RESP" | grep -o '"default_branch":"[^"]*"' | head -1 | cut -d'"' -f4)

    echo ""
    ok "Repository created successfully!"
    echo "  Name    : ${OWNER}/${REPO_NAME}"
    echo "  URL     : $HTML_URL"
    echo "  Clone   : $CLONE_URL"
    echo "  SSH     : $SSH_URL"
    echo "  Branch  : ${DEFAULT_BRANCH:-main}"
    echo ""
    echo "Next steps:"
    echo "  Clone : bash skill/scripts/gh_clone.sh --repo ${OWNER}/${REPO_NAME}"
    echo "  Or push an existing local repo:"
    echo "    git remote add origin $CLONE_URL"
    echo "    git push -u origin ${DEFAULT_BRANCH:-main}"
    ;;
  422)
    MSG=$(echo "$RESP" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
    ERRORS=$(echo "$RESP" | grep -o '"errors":\[[^]]*\]' | head -1)
    die "422 Unprocessable: $MSG $ERRORS"
    ;;
  401)
    die "401 Unauthorized — Token invalid or missing 'repo' scope. Run: gh_auth.sh --token <TOKEN>"
    ;;
  404)
    [[ -n "$ORG" ]] && die "404 — Organization '$ORG' not found or you don't have access." || die "404 Not Found"
    ;;
  *)
    die "Unexpected HTTP $HTTP_CODE: $RESP"
    ;;
esac
