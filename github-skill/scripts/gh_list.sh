#!/usr/bin/env bash
# gh_list.sh — List GitHub repositories for the authenticated user
#
# Usage:
#   gh_list.sh [--user <username>] [--limit <n>] [--search <query>] [--private-only] [--public-only]

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }

load_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then t="$(cat "$TOKEN_FILE")"
    t="${t%$'\n'}"; fi
  [[ -z "$t" ]] && die "No token. Run: gh_auth.sh --token <TOKEN>"
  echo "$t"
}

# ── parse args ────────────────────────────────────────────────────────────────
GITHUB_USER_ARG=""
LIMIT=30
SEARCH=""
VISIBILITY=""   # public | private | all (default all)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)         GITHUB_USER_ARG="${2:-}"; shift 2 ;;
    --limit)        LIMIT="${2:-30}";         shift 2 ;;
    --search)       SEARCH="${2:-}";          shift 2 ;;
    --private-only) VISIBILITY="private";     shift ;;
    --public-only)  VISIBILITY="public";      shift ;;
    --help|-h)
      echo "Usage: gh_list.sh [--user <u>] [--limit <n>] [--search <q>] [--private-only|--public-only]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

TOKEN=$(load_token)

# ── get username ──────────────────────────────────────────────────────────────
if [[ -z "$GITHUB_USER_ARG" ]]; then
  GITHUB_USER_ARG=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${API}/user" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

info "Listing repositories for: $GITHUB_USER_ARG"

# ── fetch repos ───────────────────────────────────────────────────────────────
PARAMS="per_page=${LIMIT}&sort=updated&direction=desc"
[[ -n "$VISIBILITY" ]] && PARAMS="${PARAMS}&type=${VISIBILITY}"

RESP=$(curl -sf \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${API}/users/${GITHUB_USER_ARG}/repos?${PARAMS}" 2>/dev/null) || \
  die "Failed to fetch repos. Check username and token."

# ── parse and display ─────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf " %-35s %-8s %-12s %s\n" "REPOSITORY" "VIS" "LANGUAGE" "UPDATED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

COUNT=0
# Parse JSON manually (no jq dependency)
# Each repo object is separated — extract key fields line by line
while IFS= read -r line; do
  NAME=$(echo "$line"     | grep -o '"name":"[^"]*"'       | head -1 | cut -d'"' -f4)
  PRIVATE=$(echo "$line"  | grep -o '"private":[^,}]*'     | head -1 | grep -o 'true\|false')
  LANG=$(echo "$line"     | grep -o '"language":"[^"]*"'   | head -1 | cut -d'"' -f4)
  UPDATED=$(echo "$line"  | grep -o '"updated_at":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)
  DESC=$(echo "$line"     | grep -o '"description":"[^"]*"'| head -1 | cut -d'"' -f4 | cut -c1-50)
  STARS=$(echo "$line"    | grep -o '"stargazers_count":[0-9]*' | grep -o '[0-9]*')

  [[ -z "$NAME" ]] && continue

  # Apply search filter client-side
  if [[ -n "$SEARCH" ]]; then
    echo "${NAME} ${DESC}" | grep -qi "$SEARCH" || continue
  fi

  VIS=$([[ "$PRIVATE" == "true" ]] && echo "private" || echo "public")
  LANG="${LANG:-—}"
  UPDATED="${UPDATED:-—}"

  printf " %-35s %-8s %-12s %s\n" "${GITHUB_USER_ARG}/${NAME}" "$VIS" "$LANG" "$UPDATED"
  [[ -n "$DESC" ]] && printf "   └─ %s\n" "$DESC"

  COUNT=$((COUNT + 1))
done < <(echo "$RESP" | tr '{' '\n' | grep '"name"')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total: $COUNT repositories shown"
