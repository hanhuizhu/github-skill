#!/usr/bin/env bash
# gh_push.sh — Stage all changes, commit, and push to remote
#
# Usage:
#   gh_push.sh --message "<msg>"  [--branch <branch>] [--remote <remote>]
#   gh_push.sh --message "<msg>"  --files "file1 file2"   (stage specific files)
#   gh_push.sh --push-only        (skip add/commit, just push)
#   gh_push.sh --amend            (amend last commit instead of new)

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

# ── parse args ────────────────────────────────────────────────────────────────
MSG=""
BRANCH=""
REMOTE="origin"
FILES=""          # specific files to stage (empty = all)
PUSH_ONLY=false
AMEND=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message|-m) MSG="${2:-}";    shift 2 ;;
    --branch)     BRANCH="${2:-}"; shift 2 ;;
    --remote)     REMOTE="${2:-}"; shift 2 ;;
    --files)      FILES="${2:-}";  shift 2 ;;
    --push-only)  PUSH_ONLY=true;  shift ;;
    --amend)      AMEND=true;      shift ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_push.sh --message '<msg>' [--branch <branch>] [--remote <remote>]"
      echo "  gh_push.sh --message '<msg>' --files 'file1 file2'"
      echo "  gh_push.sh --push-only"
      echo "  gh_push.sh --amend --message '<new msg>'"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── verify we're in a git repo ────────────────────────────────────────────────
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  die "Not a git repository. cd into a repo first."
fi

# ── configure token for HTTPS remote (if applicable) ─────────────────────────
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")
if echo "$REMOTE_URL" | grep -q "^https://github.com/"; then
  TOKEN="${GITHUB_TOKEN:-}"
  if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then TOKEN="$(cat "$TOKEN_FILE")"; fi
  if [[ -n "$TOKEN" ]]; then
    AUTHED_URL=$(echo "$REMOTE_URL" | sed "s|https://github.com/|https://${TOKEN}@github.com/|")
    git remote set-url "$REMOTE" "$AUTHED_URL" 2>/dev/null || true
  fi
fi

# ── determine target branch ───────────────────────────────────────────────────
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
fi

if [[ "$PUSH_ONLY" == "false" ]]; then
  # ── check for changes ─────────────────────────────────────────────────────
  STAGED=$(git diff --cached --name-only 2>/dev/null)
  UNSTAGED=$(git diff --name-only 2>/dev/null)
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)

  if [[ -z "$STAGED" && -z "$UNSTAGED" && -z "$UNTRACKED" ]]; then
    info "Nothing to commit — working tree is clean."
    info "Pushing existing commits..."
  else
    [[ -z "$MSG" && "$AMEND" == "false" ]] && die "--message is required when there are changes to commit"

    # Stage files
    if [[ -n "$FILES" ]]; then
      info "Staging: $FILES"
      # shellcheck disable=SC2086
      git add $FILES
    else
      info "Staging all changes..."
      git add -A
    fi

    # Show what will be committed
    STAGED_NOW=$(git diff --cached --name-only 2>/dev/null)
    if [[ -n "$STAGED_NOW" ]]; then
      echo "  Files to commit:"
      echo "$STAGED_NOW" | while read -r f; do echo "    + $f"; done
    fi

    # Commit
    if [[ "$AMEND" == "true" ]]; then
      if [[ -n "$MSG" ]]; then
        git commit --amend -m "$MSG"
      else
        git commit --amend --no-edit
      fi
      info "Last commit amended."
    else
      git commit -m "$MSG"
      COMMIT=$(git rev-parse --short HEAD)
      info "Committed: [$COMMIT] $MSG"
    fi
  fi
fi

# ── push ──────────────────────────────────────────────────────────────────────
info "Pushing to ${REMOTE}/${BRANCH}..."

# Set upstream if not set
if ! git rev-parse --abbrev-ref "${REMOTE}/${BRANCH}" > /dev/null 2>&1; then
  git push -u "$REMOTE" "$BRANCH"
else
  git push "$REMOTE" "$BRANCH"
fi

echo ""
ok "Pushed to ${REMOTE}/${BRANCH}"

# Restore clean remote URL (remove embedded token)
if [[ -n "${AUTHED_URL:-}" ]]; then
  git remote set-url "$REMOTE" "$REMOTE_URL" 2>/dev/null || true
fi
