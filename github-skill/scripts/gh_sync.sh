#!/usr/bin/env bash
# gh_sync.sh — Pull remote changes then push local commits (full sync)
#
# Usage:
#   gh_sync.sh [--message "<msg>"]   Commit pending changes then pull & push
#   gh_sync.sh [--push-only]         Skip pull, just push
#   gh_sync.sh [--pull-only]         Skip push, just pull

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
sep()  { echo ""; echo "──────────────────────────"; }

MSG=""
PUSH_ONLY=false
PULL_ONLY=false
BRANCH=""
REMOTE="origin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message|-m) MSG="${2:-}";    shift 2 ;;
    --push-only)  PUSH_ONLY=true;  shift ;;
    --pull-only)  PULL_ONLY=true;  shift ;;
    --branch)     BRANCH="${2:-}"; shift 2 ;;
    --remote)     REMOTE="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_sync.sh                        Pull then push (no uncommitted changes)"
      echo "  gh_sync.sh --message '<msg>'      Commit, pull, push"
      echo "  gh_sync.sh --push-only            Push only"
      echo "  gh_sync.sh --pull-only            Pull only"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

git rev-parse --git-dir > /dev/null 2>&1 || die "Not a git repository."

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
TARGET="${BRANCH:-$CURRENT}"

info "Branch: $TARGET | Remote: $REMOTE"

# ── Step 1: commit if needed ──────────────────────────────────────────────────
if [[ "$PUSH_ONLY" == "false" && "$PULL_ONLY" == "false" ]]; then
  DIRTY=$(git status --porcelain 2>/dev/null)
  if [[ -n "$DIRTY" ]]; then
    if [[ -z "$MSG" ]]; then
      die "Uncommitted changes found. Provide --message '<msg>' to commit them first."
    fi
    sep
    info "Committing changes..."
    git add -A
    git commit -m "$MSG"
    COMMIT=$(git rev-parse --short HEAD)
    ok "Committed: [$COMMIT] $MSG"
  fi
fi

# ── Step 2: pull ──────────────────────────────────────────────────────────────
if [[ "$PUSH_ONLY" == "false" ]]; then
  sep
  info "Pulling from ${REMOTE}/${TARGET}..."
  PULL_ARGS=("$SCRIPT_DIR/gh_pull.sh" "--remote" "$REMOTE")
  [[ -n "$BRANCH" ]] && PULL_ARGS+=("--branch" "$BRANCH")
  bash "${PULL_ARGS[@]}"
fi

# ── Step 3: push ──────────────────────────────────────────────────────────────
if [[ "$PULL_ONLY" == "false" ]]; then
  sep
  info "Pushing to ${REMOTE}/${TARGET}..."
  PUSH_ARGS=("$SCRIPT_DIR/gh_push.sh" "--push-only" "--branch" "$TARGET" "--remote" "$REMOTE")
  bash "${PUSH_ARGS[@]}"
fi

sep
ok "Sync complete: ${REMOTE}/${TARGET}"
