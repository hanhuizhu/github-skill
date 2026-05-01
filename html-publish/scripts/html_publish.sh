#!/usr/bin/env bash
# html_publish.sh — Main orchestrator: bundle CSS/JS → publish → return URL
#
# Steps:
#   1. Bundle: inline local CSS/JS into a single HTML (via html_bundle.py)
#   2. Publish: Plan A (GitHub Pages) or Plan B (0x0.st), auto-fallback
#   3. Print the live URL
#
# Usage:
#   html_publish.sh <html-file> [options]
#
# Options:
#   --plan a|b        Force a specific plan (default: try A, fallback B)
#   --repo <name>     GitHub repo name for Plan A (default: html-pub-<epoch>)
#   --no-bundle       Skip the bundle step (use HTML as-is)
#   --keep-bundle     Keep the bundled file at /tmp/html_publish_bundle.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="$HOME/.github_skill_token"

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
sep()  { echo ""; echo "──────────────────────────────────"; }

# ── parse args ────────────────────────────────────────────────────────────────
HTML_FILE=""
PLAN=""          # a | b | "" (auto)
REPO_NAME=""
NO_BUNDLE=false
KEEP_BUNDLE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)        PLAN="${2:-}";       shift 2 ;;
    --repo)        REPO_NAME="${2:-}";  shift 2 ;;
    --no-bundle)   NO_BUNDLE=true;      shift ;;
    --keep-bundle) KEEP_BUNDLE=true;    shift ;;
    --help|-h)
      echo "Usage: html_publish.sh <html-file> [--plan a|b] [--repo <name>] [--no-bundle]"
      exit 0 ;;
    -*)  die "Unknown option: $1" ;;
    *)   HTML_FILE="$1"; shift ;;
  esac
done

[[ -z "$HTML_FILE" ]] && die "HTML file argument is required. Usage: html_publish.sh <file.html>"
[[ -f "$HTML_FILE" ]] || die "File not found: $HTML_FILE"

HTML_ABS="$(cd "$(dirname "$HTML_FILE")" && pwd)/$(basename "$HTML_FILE")"

# ── Step 1: Bundle ────────────────────────────────────────────────────────────
sep
BUNDLE_OUT="/tmp/html_publish_bundle_$$.html"

if [[ "$NO_BUNDLE" == "true" ]]; then
  info "Skipping bundle step (--no-bundle)"
  cp "$HTML_ABS" "$BUNDLE_OUT"
else
  info "Bundling CSS/JS into single HTML..."
  python3 "$SCRIPT_DIR/html_bundle.py" "$HTML_ABS" -o "$BUNDLE_OUT"
fi

BUNDLE_SIZE=$(wc -c < "$BUNDLE_OUT" | tr -d ' ')
info "Bundle ready: ${BUNDLE_OUT} (${BUNDLE_SIZE} bytes)"

# Cleanup on exit unless --keep-bundle
[[ "$KEEP_BUNDLE" == "false" ]] && trap 'rm -f "$BUNDLE_OUT"' EXIT

# ── Step 2: Determine plan ────────────────────────────────────────────────────
sep

has_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then
    t="$(cat "$TOKEN_FILE")"; t="${t%$'\n'}"
  fi
  [[ -n "$t" ]]
}

if [[ -z "$PLAN" ]]; then
  if has_token; then
    PLAN="a"
    info "GITHUB_TOKEN found → Plan A (GitHub Pages)"
  else
    PLAN="b"
    info "No GITHUB_TOKEN → Plan B (Litterbox)"
  fi
fi

# ── Step 3: Publish ───────────────────────────────────────────────────────────
LIVE_URL=""

publish_plan_a() {
  info "Publishing via GitHub Pages..."
  GHPAGES_ARGS=("$BUNDLE_OUT")
  [[ -n "$REPO_NAME" ]] && GHPAGES_ARGS+=("--repo" "$REPO_NAME")
  OUTPUT=$(bash "$SCRIPT_DIR/html_ghpages.sh" "${GHPAGES_ARGS[@]}" 2>&1) || return 1
  echo "$OUTPUT"
  # Last non-empty line is the URL
  LIVE_URL=$(echo "$OUTPUT" | grep -E '^https?://' | tail -1)
  [[ -n "$LIVE_URL" ]]
}

publish_plan_b() {
  info "Publishing via Litterbox (litter.catbox.moe)..."
  OUTPUT=$(bash "$SCRIPT_DIR/html_gist.sh" "$BUNDLE_OUT" 2>&1) || return 1
  echo "$OUTPUT"
  LIVE_URL=$(echo "$OUTPUT" | grep -E '^https?://' | tail -1)
  [[ -n "$LIVE_URL" ]]
}

case "$PLAN" in
  a)
    if ! publish_plan_a; then
      sep
      info "Plan A failed — falling back to Plan B (0x0.st)..."
      publish_plan_b || die "Both Plan A and Plan B failed."
    fi
    ;;
  b)
    publish_plan_b || die "Plan B (0x0.st) failed. Check network."
    ;;
  *)
    die "Unknown plan: $PLAN. Use 'a' or 'b'."
    ;;
esac

# ── Final output ──────────────────────────────────────────────────────────────
sep
ok "Published successfully!"
echo ""
echo "  🌐 URL   : $LIVE_URL"
echo "  📦 Size  : ${BUNDLE_SIZE} bytes (single-file HTML)"
echo ""
