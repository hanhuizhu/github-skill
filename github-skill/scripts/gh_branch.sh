#!/usr/bin/env bash
# gh_branch.sh — Branch management (create, switch, list, delete)
#
# Usage:
#   gh_branch.sh --list
#   gh_branch.sh --create --name <branch> [--from <base>]
#   gh_branch.sh --switch --name <branch>
#   gh_branch.sh --delete --name <branch> [--force]

set -euo pipefail

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

# ── parse args ────────────────────────────────────────────────────────────────
ACTION=""
BRANCH_NAME=""
BASE_BRANCH=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)   ACTION="list";   shift ;;
    --create) ACTION="create"; shift ;;
    --switch) ACTION="switch"; shift ;;
    --delete) ACTION="delete"; shift ;;
    --name)   BRANCH_NAME="${2:-}"; shift 2 ;;
    --from)   BASE_BRANCH="${2:-}"; shift 2 ;;
    --force)  FORCE=true; shift ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_branch.sh --list"
      echo "  gh_branch.sh --create --name <branch> [--from <base-branch>]"
      echo "  gh_branch.sh --switch --name <branch>"
      echo "  gh_branch.sh --delete --name <branch> [--force]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -z "$ACTION" ]] && die "Specify --list, --create, --switch, or --delete"
git rev-parse --git-dir > /dev/null 2>&1 || die "Not a git repository."

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

# ── actions ───────────────────────────────────────────────────────────────────
case "$ACTION" in
  list)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Branches"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    git branch -a --format='%(refname:short) %(upstream:short) %(objectname:short)' 2>/dev/null | \
    while read -r bname upstream sha; do
      marker=$([[ "$bname" == "$CURRENT" ]] && echo "▶ " || echo "  ")
      remote_info=$([[ -n "$upstream" ]] && echo "  → $upstream" || echo "")
      echo "${marker}${bname} [${sha}]${remote_info}"
    done
    echo ""
    echo "Current branch: $CURRENT"
    ;;

  create)
    [[ -z "$BRANCH_NAME" ]] && die "--name is required"
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
      die "Branch '$BRANCH_NAME' already exists. Use --switch to switch to it."
    fi

    if [[ -n "$BASE_BRANCH" ]]; then
      info "Creating '$BRANCH_NAME' from '$BASE_BRANCH'..."
      git checkout -b "$BRANCH_NAME" "$BASE_BRANCH"
    else
      info "Creating '$BRANCH_NAME' from current ($CURRENT)..."
      git checkout -b "$BRANCH_NAME"
    fi
    ok "Switched to new branch: $BRANCH_NAME"
    echo ""
    echo "Push to remote: bash skill/scripts/gh_push.sh --push-only --branch $BRANCH_NAME"
    ;;

  switch)
    [[ -z "$BRANCH_NAME" ]] && die "--name is required"
    if [[ "$BRANCH_NAME" == "$CURRENT" ]]; then
      info "Already on branch '$BRANCH_NAME'"
      exit 0
    fi

    # Check for uncommitted changes
    DIRTY=$(git status --porcelain 2>/dev/null)
    if [[ -n "$DIRTY" ]]; then
      die "Uncommitted changes detected. Commit or stash first:\n  git stash\n  gh_branch.sh --switch --name $BRANCH_NAME"
    fi

    # Try local branch first, then remote tracking
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
      git checkout "$BRANCH_NAME"
    elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
      info "Checking out remote branch origin/$BRANCH_NAME..."
      git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
    else
      die "Branch '$BRANCH_NAME' not found locally or on origin. Use --create to create it."
    fi
    ok "Switched to: $BRANCH_NAME"
    ;;

  delete)
    [[ -z "$BRANCH_NAME" ]] && die "--name is required"
    [[ "$BRANCH_NAME" == "$CURRENT" ]] && die "Cannot delete the current branch. Switch first."

    if [[ "$FORCE" == "true" ]]; then
      git branch -D "$BRANCH_NAME"
    else
      git branch -d "$BRANCH_NAME" || \
        die "Branch has unmerged commits. Use --force to delete anyway."
    fi
    ok "Deleted local branch: $BRANCH_NAME"
    echo ""
    echo "To delete remote branch: git push origin --delete $BRANCH_NAME"
    ;;
esac
