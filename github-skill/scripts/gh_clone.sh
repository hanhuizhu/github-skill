#!/usr/bin/env bash
# gh_clone.sh — Clone a GitHub repository
#
# Usage:
#   gh_clone.sh --repo <owner/repo>  [--dir <path>] [--branch <branch>] [--ssh]
#   gh_clone.sh --url  <full-url>    [--dir <path>] [--branch <branch>]
#
# Token from GITHUB_TOKEN env or ~/.github_skill_token is used for HTTPS auth.

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
  echo "$t"
}

# ── parse args ────────────────────────────────────────────────────────────────
REPO=""       # owner/repo format
CLONE_URL=""  # full URL (alternative input)
TARGET_DIR="" # destination directory
BRANCH=""
USE_SSH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="${2:-}";       shift 2 ;;
    --url)     CLONE_URL="${2:-}";  shift 2 ;;
    --dir)     TARGET_DIR="${2:-}"; shift 2 ;;
    --branch)  BRANCH="${2:-}";     shift 2 ;;
    --ssh)     USE_SSH=true;        shift ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_clone.sh --repo <owner/repo> [--dir <path>] [--branch <name>] [--ssh]"
      echo "  gh_clone.sh --url  <https://github.com/...> [--dir <path>] [--branch <name>]"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

# Accept GitHub URL as --repo value too
if [[ -n "$REPO" ]]; then
  REPO="${REPO#https://github.com/}"
  REPO="${REPO%.git}"
fi

[[ -z "$REPO" && -z "$CLONE_URL" ]] && die "Specify --repo <owner/repo> or --url <url>"

# ── build clone URL ───────────────────────────────────────────────────────────
TOKEN=$(load_token)

if [[ -n "$CLONE_URL" ]]; then
  FULL_URL="$CLONE_URL"
  # Extract owner/repo from URL for display
  REPO=$(echo "$CLONE_URL" | sed 's|https://github.com/||;s|\.git$||;s|git@github.com:||')
elif [[ "$USE_SSH" == "true" ]]; then
  FULL_URL="git@github.com:${REPO}.git"
elif [[ -n "$TOKEN" ]]; then
  FULL_URL="https://${TOKEN}@github.com/${REPO}.git"
else
  FULL_URL="https://github.com/${REPO}.git"
fi

DISPLAY_URL="https://github.com/${REPO}"

# ── determine destination ─────────────────────────────────────────────────────
REPO_NAME="${REPO##*/}"
if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="./${REPO_NAME}"
fi

if [[ -d "$TARGET_DIR" ]]; then
  die "Destination already exists: $TARGET_DIR — choose a different --dir"
fi

# ── clone ─────────────────────────────────────────────────────────────────────
info "Cloning ${DISPLAY_URL}"
info "Destination: $TARGET_DIR"
[[ -n "$BRANCH" ]] && info "Branch: $BRANCH"

CLONE_ARGS=("$FULL_URL" "$TARGET_DIR")
[[ -n "$BRANCH" ]] && CLONE_ARGS=("--branch" "$BRANCH" "${CLONE_ARGS[@]}")

if ! git clone "${CLONE_ARGS[@]}"; then
  die "git clone failed. Check repo name, permissions, and network."
fi

echo ""
ok "Cloned successfully to: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  bash skill/scripts/gh_status.sh   # view status"
echo "  bash skill/scripts/gh_push.sh     # push changes"
