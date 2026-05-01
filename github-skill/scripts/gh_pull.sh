#!/usr/bin/env bash
# gh_pull.sh — Pull latest changes from remote
#
# Usage:
#   gh_pull.sh [--branch <branch>] [--remote <remote>] [--rebase]

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

BRANCH=""
REMOTE="origin"
REBASE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --rebase) REBASE=true;     shift ;;
    --help|-h)
      echo "Usage: gh_pull.sh [--branch <branch>] [--remote <remote>] [--rebase]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

git rev-parse --git-dir > /dev/null 2>&1 || die "Not a git repository."

# Inject token for HTTPS remotes
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")
AUTHED_URL=""
if echo "$REMOTE_URL" | grep -q "^https://github.com/"; then
  TOKEN="${GITHUB_TOKEN:-}"
  if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then TOKEN="$(cat "$TOKEN_FILE")"; fi
  if [[ -n "$TOKEN" ]]; then
    AUTHED_URL=$(echo "$REMOTE_URL" | sed "s|https://github.com/|https://${TOKEN}@github.com/|")
    git remote set-url "$REMOTE" "$AUTHED_URL" 2>/dev/null || true
  fi
fi

CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
TARGET="${BRANCH:-$CURRENT_BRANCH}"

info "Pulling ${REMOTE}/${TARGET}..."

PULL_ARGS=("$REMOTE")
[[ -n "$TARGET" ]] && PULL_ARGS+=("$TARGET")
[[ "$REBASE" == "true" ]] && PULL_ARGS=("--rebase" "${PULL_ARGS[@]}")

if git pull "${PULL_ARGS[@]}"; then
  echo ""
  ok "Up to date with ${REMOTE}/${TARGET}"
  git log --oneline -5 --decorate
else
  # Restore URL before exiting
  [[ -n "$AUTHED_URL" ]] && git remote set-url "$REMOTE" "$REMOTE_URL" 2>/dev/null || true
  die "git pull failed. Check for merge conflicts or network issues."
fi

# Restore clean URL
[[ -n "$AUTHED_URL" ]] && git remote set-url "$REMOTE" "$REMOTE_URL" 2>/dev/null || true
