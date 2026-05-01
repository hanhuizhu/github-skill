#!/usr/bin/env bash
# gh_pr.sh — Pull Request management via GitHub REST API
#
# Usage:
#   gh_pr.sh --list   [--state open|closed|all]
#   gh_pr.sh --create --title "<title>" [--body "<body>"] [--base <branch>] [--draft]
#   gh_pr.sh --view   --number <n>
#   gh_pr.sh --merge  --number <n>  [--method merge|squash|rebase]

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

load_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then t="$(cat "$TOKEN_FILE")"
    t="${t%$'\n'}"; fi
  [[ -z "$t" ]] && die "No token. Run: gh_auth.sh --token <TOKEN>"
  echo "$t"
}

get_repo_slug() {
  local url
  url=$(git remote get-url origin 2>/dev/null || echo "")
  [[ -z "$url" ]] && die "No 'origin' remote. This repo isn't linked to GitHub."
  echo "$url" | sed 's|.*github\.com[:/]||;s|\.git$||'
}

# ── parse args ────────────────────────────────────────────────────────────────
ACTION=""
STATE="open"
PR_TITLE=""
PR_BODY=""
BASE_BRANCH=""
PR_NUMBER=""
DRAFT=false
MERGE_METHOD="merge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)   ACTION="list";   shift ;;
    --create) ACTION="create"; shift ;;
    --view)   ACTION="view";   shift ;;
    --merge)  ACTION="merge";  shift ;;
    --state)  STATE="${2:-open}"; shift 2 ;;
    --title)  PR_TITLE="${2:-}";  shift 2 ;;
    --body)   PR_BODY="${2:-}";   shift 2 ;;
    --base)   BASE_BRANCH="${2:-}"; shift 2 ;;
    --number) PR_NUMBER="${2:-}"; shift 2 ;;
    --draft)  DRAFT=true;         shift ;;
    --method) MERGE_METHOD="${2:-merge}"; shift 2 ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_pr.sh --list [--state open|closed|all]"
      echo "  gh_pr.sh --create --title '<title>' [--body '<body>'] [--base <branch>] [--draft]"
      echo "  gh_pr.sh --view  --number <n>"
      echo "  gh_pr.sh --merge --number <n> [--method merge|squash|rebase]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -z "$ACTION" ]] && die "Specify --list, --create, --view, or --merge"
git rev-parse --git-dir > /dev/null 2>&1 || die "Not a git repository."

TOKEN=$(load_token)
REPO=$(get_repo_slug)

# ── actions ───────────────────────────────────────────────────────────────────
case "$ACTION" in
  list)
    info "Fetching $STATE PRs for ${REPO}..."
    RESP=$(curl -sf \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${API}/repos/${REPO}/pulls?state=${STATE}&per_page=20") || die "API request failed."

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf " %-6s %-40s %-14s %s\n" "#" "TITLE" "FROM → BASE" "AUTHOR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    COUNT=0
    while IFS= read -r line; do
      NUM=$(echo "$line"    | grep -o '"number":[0-9]*'          | head -1 | grep -o '[0-9]*')
      TITLE=$(echo "$line"  | grep -o '"title":"[^"]*"'          | head -1 | cut -d'"' -f4 | cut -c1-40)
      HEAD=$(echo "$line"   | grep -o '"ref":"[^"]*"'            | head -1 | cut -d'"' -f4)
      BASE=$(echo "$line"   | grep -o '"base":{[^}]*}'           | grep -o '"ref":"[^"]*"' | head -1 | cut -d'"' -f4)
      AUTHOR=$(echo "$line" | grep -o '"user":{[^}]*}'           | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
      DRAFT_FLAG=$(echo "$line" | grep -o '"draft":[^,}]*'       | head -1 | grep -o 'true\|false')

      [[ -z "$NUM" ]] && continue
      DRAFT_LABEL=$([[ "$DRAFT_FLAG" == "true" ]] && echo " [DRAFT]" || echo "")
      printf " %-6s %-40s %-14s %s\n" "#${NUM}" "${TITLE}${DRAFT_LABEL}" "${HEAD}→${BASE}" "$AUTHOR"
      COUNT=$((COUNT+1))
    done < <(echo "$RESP" | tr '{' '\n' | grep '"number":[0-9]')

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total: $COUNT PRs"
    ;;

  create)
    [[ -z "$PR_TITLE" ]] && die "--title is required"

    CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || die "Cannot determine current branch")
    HEAD_BRANCH="$CURRENT"

    # Default base to default branch
    if [[ -z "$BASE_BRANCH" ]]; then
      BASE_BRANCH=$(curl -sf \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "${API}/repos/${REPO}" | grep -o '"default_branch":"[^"]*"' | head -1 | cut -d'"' -f4)
      BASE_BRANCH="${BASE_BRANCH:-main}"
    fi

    [[ "$HEAD_BRANCH" == "$BASE_BRANCH" ]] && \
      die "Head branch ($HEAD_BRANCH) and base branch ($BASE_BRANCH) are the same."

    info "Creating PR: '$PR_TITLE'"
    info "  ${HEAD_BRANCH} → ${BASE_BRANCH}"

    PAYLOAD=$(cat <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$HEAD_BRANCH",
  "base": "$BASE_BRANCH",
  "draft": $DRAFT
}
EOF
)

    HTTP_CODE=$(curl -s -o /tmp/gh_pr_resp.json -w "%{http_code}" \
      -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${API}/repos/${REPO}/pulls")

    RESP=$(cat /tmp/gh_pr_resp.json); rm -f /tmp/gh_pr_resp.json

    case "$HTTP_CODE" in
      201)
        PR_URL=$(echo "$RESP" | grep -o '"html_url":"[^"]*"' | head -1 | cut -d'"' -f4)
        PR_NUM=$(echo "$RESP" | grep -o '"number":[0-9]*'    | head -1 | grep -o '[0-9]*')
        echo ""
        ok "PR created: #${PR_NUM}"
        echo "  Title : $PR_TITLE"
        echo "  URL   : $PR_URL"
        [[ "$DRAFT" == "true" ]] && echo "  Status: Draft"
        ;;
      422)
        MSG=$(echo "$RESP" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
        die "422: $MSG"
        ;;
      *)
        die "HTTP $HTTP_CODE: $RESP"
        ;;
    esac
    ;;

  view)
    [[ -z "$PR_NUMBER" ]] && die "--number is required"
    RESP=$(curl -sf \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${API}/repos/${REPO}/pulls/${PR_NUMBER}") || die "PR #${PR_NUMBER} not found."

    TITLE=$(echo "$RESP"  | grep -o '"title":"[^"]*"'         | head -1 | cut -d'"' -f4)
    STATE_V=$(echo "$RESP"| grep -o '"state":"[^"]*"'         | head -1 | cut -d'"' -f4)
    AUTHOR=$(echo "$RESP" | grep -o '"user":{[^}]*}'          | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
    URL=$(echo "$RESP"    | grep -o '"html_url":"[^"]*"'      | head -1 | cut -d'"' -f4)
    BODY=$(echo "$RESP"   | grep -o '"body":"[^"]*"'          | head -1 | cut -d'"' -f4 | cut -c1-300)
    MERGED=$(echo "$RESP" | grep -o '"merged":[^,}]*'         | head -1 | grep -o 'true\|false')

    echo ""
    echo "PR #${PR_NUMBER}: $TITLE"
    echo "  Status : $STATE_V$([[ "$MERGED" == "true" ]] && echo " (merged)")"
    echo "  Author : $AUTHOR"
    echo "  URL    : $URL"
    [[ -n "$BODY" ]] && echo "  Body   : $BODY"
    ;;

  merge)
    [[ -z "$PR_NUMBER" ]] && die "--number is required"
    info "Merging PR #${PR_NUMBER} using method: $MERGE_METHOD"

    PAYLOAD="{\"merge_method\": \"$MERGE_METHOD\"}"
    HTTP_CODE=$(curl -s -o /tmp/gh_pr_merge.json -w "%{http_code}" \
      -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${API}/repos/${REPO}/pulls/${PR_NUMBER}/merge")

    RESP=$(cat /tmp/gh_pr_merge.json); rm -f /tmp/gh_pr_merge.json

    case "$HTTP_CODE" in
      200) ok "PR #${PR_NUMBER} merged successfully." ;;
      405) die "PR is not mergeable (conflicts or not open)." ;;
      409) die "Head branch was modified — re-check the PR." ;;
      *)   die "HTTP $HTTP_CODE: $RESP" ;;
    esac
    ;;
esac
