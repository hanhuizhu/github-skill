#!/usr/bin/env bash
# gh_status.sh — Show current git + GitHub repo status
#
# Usage:
#   gh_status.sh [--short]

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }

SHORT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --short|-s) SHORT=true; shift ;;
    --help|-h)
      echo "Usage: gh_status.sh [--short]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

git rev-parse --git-dir > /dev/null 2>&1 || die "Not a git repository."

# ── basic git info ────────────────────────────────────────────────────────────
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "no remote")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Git Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Branch : $BRANCH"
echo "  Remote : $REMOTE_URL"

# Ahead/behind
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "")
if [[ -n "$UPSTREAM" ]]; then
  AHEAD=$(git rev-list --count "${UPSTREAM}..HEAD" 2>/dev/null || echo 0)
  BEHIND=$(git rev-list --count "HEAD..${UPSTREAM}" 2>/dev/null || echo 0)
  [[ "$AHEAD" -gt 0 ]]  && echo "  Ahead  : $AHEAD commit(s) to push"
  [[ "$BEHIND" -gt 0 ]] && echo "  Behind : $BEHIND commit(s) to pull"
  [[ "$AHEAD" -eq 0 && "$BEHIND" -eq 0 ]] && echo "  Sync   : up to date with remote"
else
  echo "  Sync   : no upstream tracking branch"
fi

# Working tree
STAGED=$(git diff --cached --name-only 2>/dev/null)
MODIFIED=$(git diff --name-only 2>/dev/null)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)

echo ""
if [[ -z "$STAGED" && -z "$MODIFIED" && -z "$UNTRACKED" ]]; then
  echo "  Working tree: clean"
else
  [[ -n "$STAGED"    ]] && echo "  Staged    ($(echo "$STAGED"    | wc -l | tr -d ' ') files):" && echo "$STAGED"    | while read -r f; do echo "    ✚ $f"; done
  [[ -n "$MODIFIED"  ]] && echo "  Modified  ($(echo "$MODIFIED"  | wc -l | tr -d ' ') files):" && echo "$MODIFIED"  | while read -r f; do echo "    ✎ $f"; done
  [[ -n "$UNTRACKED" ]] && echo "  Untracked ($(echo "$UNTRACKED" | wc -l | tr -d ' ') files):" && echo "$UNTRACKED" | while read -r f; do echo "    ? $f"; done
fi

if [[ "$SHORT" == "true" ]]; then exit 0; fi

# ── recent commits ────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Recent Commits"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
git log --oneline --decorate -8 2>/dev/null || echo "  (no commits yet)"

# ── GitHub API info (if available) ───────────────────────────────────────────
REPO_SLUG=""
if echo "$REMOTE_URL" | grep -qE "(github.com[:/])"; then
  REPO_SLUG=$(echo "$REMOTE_URL" | sed 's|.*github\.com[:/]||;s|\.git$||')
fi

if [[ -n "$REPO_SLUG" ]]; then
  TOKEN="${GITHUB_TOKEN:-}"
  if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then TOKEN="$(cat "$TOKEN_FILE")"; fi

  if [[ -n "$TOKEN" ]]; then
    REPO_INFO=$(curl -sf \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${API}/repos/${REPO_SLUG}" 2>/dev/null || echo "")

    if [[ -n "$REPO_INFO" ]]; then
      STARS=$(echo "$REPO_INFO"  | grep -o '"stargazers_count":[0-9]*' | grep -o '[0-9]*')
      FORKS=$(echo "$REPO_INFO"  | grep -o '"forks_count":[0-9]*'      | grep -o '[0-9]*')
      ISSUES=$(echo "$REPO_INFO" | grep -o '"open_issues_count":[0-9]*' | grep -o '[0-9]*')
      PRIVATE=$(echo "$REPO_INFO" | grep -o '"private":[^,}]*'          | grep -o 'true\|false')

      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " GitHub: ${REPO_SLUG}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Visibility : $([[ "$PRIVATE" == "true" ]] && echo "private" || echo "public")"
      echo "  Stars      : ${STARS:-0}"
      echo "  Forks      : ${FORKS:-0}"
      echo "  Open Issues: ${ISSUES:-0}"
      echo "  URL        : https://github.com/${REPO_SLUG}"
    fi
  fi
fi
