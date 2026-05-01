#!/usr/bin/env bash
# gh_auth.sh — Configure and verify GitHub Personal Access Token
#
# Usage:
#   gh_auth.sh --token <TOKEN>   Save token and verify
#   gh_auth.sh --check           Check current token validity
#   gh_auth.sh --show-user       Print authenticated username

set -euo pipefail

TOKEN_FILE="$HOME/.github_skill_token"
API="https://api.github.com"

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

load_token() {
  local t="${GITHUB_TOKEN:-}"
  if [[ -z "$t" && -f "$TOKEN_FILE" ]]; then
    t="$(cat "$TOKEN_FILE")"
    t="${t%$'\n'}"   # strip trailing newline
  fi
  echo "$t"
}

verify_token() {
  local token="$1"
  local resp
  resp=$(curl -s -H "Authorization: Bearer $token" \
               -H "Accept: application/vnd.github+json" \
               -H "X-GitHub-Api-Version: 2022-11-28" \
               "${API}/user")
  if echo "$resp" | grep -q '"login"'; then
    echo "$resp"
  else
    echo ""
    return 1
  fi
}

# ── parse args ────────────────────────────────────────────────────────────────
ACTION=""
NEW_TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)     ACTION="save"; NEW_TOKEN="${2:-}"; shift 2 ;;
    --check)     ACTION="check"; shift ;;
    --show-user) ACTION="user"; shift ;;
    --help|-h)
      echo "Usage:"
      echo "  gh_auth.sh --token <TOKEN>   Save and verify token"
      echo "  gh_auth.sh --check           Check current token"
      echo "  gh_auth.sh --show-user       Show authenticated user"
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -z "$ACTION" ]] && die "No action specified. Use --token, --check, or --show-user"

# ── actions ───────────────────────────────────────────────────────────────────
case "$ACTION" in
  save)
    [[ -z "$NEW_TOKEN" ]] && die "--token requires a value (e.g. ghp_xxxxx)"

    info "Verifying token..."
    resp=$(verify_token "$NEW_TOKEN")
    if [[ -z "$resp" ]]; then
      die "Token verification failed. Check the token is valid and has 'repo' + 'read:user' scopes."
    fi

    login=$(echo "$resp" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)

    echo "$NEW_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    ok "Token saved to $TOKEN_FILE"
    ok "Authenticated as: $login"
    echo ""
    echo "Token will be used automatically by all gh_*.sh scripts."
    ;;

  check)
    token=$(load_token)
    [[ -z "$token" ]] && die "No token found. Run: gh_auth.sh --token <YOUR_TOKEN>"

    info "Checking token..."
    resp=$(verify_token "$token")
    if [[ -z "$resp" ]]; then
      die "Token is invalid or expired. Run: gh_auth.sh --token <NEW_TOKEN>"
    fi

    login=$(echo "$resp" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
    name=$(echo "$resp"  | grep -o '"name":"[^"]*"'  | head -1 | cut -d'"' -f4)
    repos=$(echo "$resp" | grep -o '"public_repos":[0-9]*' | head -1 | grep -o '[0-9]*')

    ok "Token is valid"
    echo "  User    : $login (${name:-no name})"
    echo "  Repos   : $repos public repos"
    ;;

  user)
    token=$(load_token)
    [[ -z "$token" ]] && die "No token configured."
    resp=$(verify_token "$token")
    [[ -z "$resp" ]] && die "Token invalid."
    echo "$resp" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4
    ;;
esac
