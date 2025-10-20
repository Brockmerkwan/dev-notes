#!/usr/bin/env bash
set -euo pipefail

REG="ghcr.io"
USER="${1:-brockmerkwan}"   # allow override: ./scripts/fix_ghcr_login.sh otheruser
CONF="$HOME/.docker/config.json"

echo "🔧 Fixing GHCR login for $USER @ $REG"

# Ensure config exists and back it up
mkdir -p "$(dirname "$CONF")"
touch "$CONF"
cp "$CONF" "$CONF.bak.$(date +%s)" || true

# Strip stale ghcr entries
tmp="$(mktemp)"
if command -v jq >/dev/null 2>&1; then
  jq '(.auths // {}) as $a
      | $a | del(.["ghcr.io"]) | del(.["https://ghcr.io"])
      | . as $clean
      | {"auths": $clean}' "$CONF" 2>/dev/null >"$tmp" || echo '{"auths":{}}' >"$tmp"
else
  # jq not present; write minimal auths block
  echo '{"auths":{}}' >"$tmp"
fi
mv "$tmp" "$CONF"

# Remove keychain entries if present
helper="$(jq -r '.credsStore // empty' "$CONF" 2>/dev/null || true)"
if [ "$helper" = "osxkeychain" ] && command -v docker-credential-osxkeychain >/dev/null 2>&1; then
  { printf "https://ghcr.io\n" | docker-credential-osxkeychain erase; } 2>/dev/null || true
  { printf "ghcr.io\n"         | docker-credential-osxkeychain erase; } 2>/dev/null || true
fi

# Force logout then login
docker logout "$REG" >/dev/null 2>&1 || true
echo
echo "🔑 Enter a GitHub PAT for $USER (needs at least read:packages)"
read -r -s -p "GitHub PAT: " PAT
echo
echo "$PAT" | docker login "$REG" -u "$USER" --password-stdin

# Sanity check
code="$(curl -s -o /dev/null -w "%{http_code}" -u "$USER:$PAT" "https://$REG/v2/")"
echo "GHCR /v2/ check → HTTP $code"
if [ "$code" != "200" ]; then
  echo "❌ Auth check failed (HTTP $code) — verify PAT and SSO access."
  exit 2
fi

echo "✅ GHCR credentials repaired."
