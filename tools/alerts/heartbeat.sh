#!/usr/bin/env bash
set -euo pipefail
TS=$(date "+%F %T")
curl -sS -H "Title: AI Watcher Heartbeat" -d "Alive @ $TS" https://ntfy.sh/brock-live-feed >/dev/null || true
echo "heartbeat sent → brock-live-feed | $TS"
