#!/usr/bin/env bash
# html_selftest.sh — Self-validation for html-publish skill
#
# Tests:
#   1. Bundle: creates a temp HTML with external CSS+JS, runs html_bundle.py,
#              verifies the output contains inlined content
#   2. Publish (Plan B / 0x0.st): publishes the bundled HTML, curls the URL,
#              verifies HTTP 200 and content match
#   3. (Optional) Plan A: skipped by default unless --test-ghpages is passed
#
# Usage:
#   html_selftest.sh [--test-ghpages] [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die()   { echo "[FAIL]  $*" >&2; FAILURES=$((FAILURES+1)); }
pass()  { echo "[PASS]  $*"; PASSES=$((PASSES+1)); }
info()  { echo "[INFO]  $*"; }
sep()   { echo ""; echo "══════════════════════════════════════"; }

FAILURES=0
PASSES=0
TEST_GHPAGES=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-ghpages) TEST_GHPAGES=true; shift ;;
    --verbose|-v)   VERBOSE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── Test 1: Bundle ─────────────────────────────────────────────────────────
sep
info "Test 1: html_bundle.py — inline CSS and JS"

# Create test fixtures
cat > "$TMPDIR_TEST/style.css" <<'EOF'
body {
  /* test comment */
  background: #fff;
  color: #333;
  margin: 0;
}
.container {
  max-width: 800px;
  margin: 0 auto;
}
EOF

cat > "$TMPDIR_TEST/app.js" <<'EOF'
// test comment
function greet(name) {
  return 'Hello, ' + name + '!';
}
document.addEventListener('DOMContentLoaded', function() {
  console.log(greet('world'));
});
EOF

cat > "$TMPDIR_TEST/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Test Page</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="container">
    <h1>Hello World</h1>
    <p>This is a self-test page.</p>
  </div>
  <script src="app.js"></script>
</body>
</html>
EOF

BUNDLE_OUT="$TMPDIR_TEST/bundled.html"
python3 "$SCRIPT_DIR/html_bundle.py" "$TMPDIR_TEST/index.html" -o "$BUNDLE_OUT" 2>&1 | \
  { [[ "$VERBOSE" == "true" ]] && cat || grep -E '^\[' || true; }

# Verify bundle output
if [[ ! -f "$BUNDLE_OUT" ]]; then
  die "Bundle output file not created"
else
  # Check CSS was inlined
  if grep -q '<style>' "$BUNDLE_OUT" && grep -q 'background' "$BUNDLE_OUT"; then
    pass "CSS inlined correctly"
  else
    die "CSS not found in bundled output"
  fi

  # Check JS was inlined
  if grep -q '<script>' "$BUNDLE_OUT" && grep -q 'greet' "$BUNDLE_OUT"; then
    pass "JS inlined correctly"
  else
    die "JS not found in bundled output"
  fi

  # Check original <link> and <script src=> are gone
  if grep -q 'href="style.css"' "$BUNDLE_OUT"; then
    die "<link> tag still present after bundle"
  else
    pass "<link> tag removed"
  fi

  if grep -q 'src="app.js"' "$BUNDLE_OUT"; then
    die "<script src> still present after bundle"
  else
    pass "<script src> removed"
  fi

  # Check minification reduced comments
  if grep -q '/* test comment */' "$BUNDLE_OUT"; then
    die "CSS comment not stripped by minifier"
  else
    pass "CSS comments stripped"
  fi

  # Remote URLs untouched (add one to test)
  cat > "$TMPDIR_TEST/remote_test.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://cdn.example.com/remote.css">
  <link rel="stylesheet" href="style.css">
</head>
<body><script src="https://cdn.example.com/remote.js"></script></body>
</html>
EOF
  REMOTE_OUT="$TMPDIR_TEST/remote_bundled.html"
  python3 "$SCRIPT_DIR/html_bundle.py" "$TMPDIR_TEST/remote_test.html" -o "$REMOTE_OUT" 2>/dev/null
  if grep -q 'href="https://cdn.example.com/remote.css"' "$REMOTE_OUT"; then
    pass "Remote CSS URL left untouched"
  else
    die "Remote CSS URL was incorrectly processed"
  fi
fi

# ── Test 2: Publish Plan B (0x0.st) ─────────────────────────────────────────
sep
info "Test 2: html_gist.sh — publish via GitHub Gist + htmlpreview.github.io"

PUBLISH_OUT=$(bash "$SCRIPT_DIR/html_gist.sh" "$BUNDLE_OUT" --desc "html-publish selftest" 2>&1) || {
  die "html_gist.sh exited with error"
}
[[ "$VERBOSE" == "true" ]] && echo "$PUBLISH_OUT"

LIVE_URL=$(echo "$PUBLISH_OUT" | grep -E '^https?://litter\.catbox\.moe/' | tail -1 || echo "")

if [[ -z "$LIVE_URL" ]]; then
  die "No URL returned from html_gist.sh"
else
  pass "URL returned: $LIVE_URL"

  # curl the URL and verify
  HTTP_CODE=$(curl -s -o /tmp/selftest_page.html -w "%{http_code}" --max-time 15 "$LIVE_URL" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "URL is accessible (HTTP 200)"
    # Check content
    if grep -q 'Hello World' /tmp/selftest_page.html 2>/dev/null; then
      pass "Page content verified ('Hello World' found)"
    else
      die "Page content mismatch — expected 'Hello World'"
    fi
  else
    die "URL returned HTTP ${HTTP_CODE} (expected 200)"
  fi
  rm -f /tmp/selftest_page.html
fi

# ── Test 3: Plan A (GitHub Pages) — optional ─────────────────────────────────
if [[ "$TEST_GHPAGES" == "true" ]]; then
  sep
  info "Test 3: html_ghpages.sh — publish via GitHub Pages"

  GHP_OUT=$(bash "$SCRIPT_DIR/html_ghpages.sh" "$BUNDLE_OUT" --repo "html-selftest-$(date +%s)" 2>&1) || {
    die "html_ghpages.sh failed"
  }
  [[ "$VERBOSE" == "true" ]] && echo "$GHP_OUT"

  GHP_URL=$(echo "$GHP_OUT" | grep -E '^https?://' | tail -1 || echo "")
  if [[ -n "$GHP_URL" ]]; then
    pass "GitHub Pages URL: $GHP_URL"
  else
    die "No GitHub Pages URL returned"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
sep
echo ""
echo "  Passed : $PASSES"
echo "  Failed : $FAILURES"
echo ""

if [[ $FAILURES -gt 0 ]]; then
  echo "  ✗ Self-test FAILED"
  exit 1
else
  echo "  ✓ All tests passed"
  [[ -n "${LIVE_URL:-}" ]] && echo "  🌐 Live URL : $LIVE_URL"
fi
