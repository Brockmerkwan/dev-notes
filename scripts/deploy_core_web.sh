#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-tools/core_dash_web.py}"
PORT="${CORE_DASH_PORT:-7780}"
TMP="/tmp/core_dash_web.$$"
PY="$(command -v python3)"

# 1) Compile
$PY -m py_compile "$SRC"

# 2) Ephemeral bind test on another port (no launchd)
TEST_PORT=$(( PORT + 1 ))
CORE_TOKEN="testtoken" CORE_DASH_PORT="$TEST_PORT" $PY "$SRC" &
PID=$!
sleep 0.5

# 3) Smoke: 401 w/o token, 200 with token
code401=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${TEST_PORT}/api/status" || true)
code200=$(curl -s -o /dev/null -H "Authorization: Bearer testtoken" -w "%{http_code}" "http://127.0.0.1:${TEST_PORT}/api/status" || true)
kill $PID 2>/dev/null || true

[ "$code401" = "401" ] && [ "$code200" = "200" ] || { echo "❌ smoke failed ($code401/$code200)"; exit 1; }

# 4) Install + restart launchd
launchctl bootout gui/$(id -u)/com.brock.dashboard.http 2>/dev/null || true
pkill -f core_dash_web.py 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.brock.dashboard.http.plist
launchctl enable   gui/$(id -u)/com.brock.dashboard.http
launchctl kickstart -k gui/$(id -u)/com.brock.dashboard.http

echo "✅ deployed"
