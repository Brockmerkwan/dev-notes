#!/usr/bin/env bash
set -euo pipefail
CONF="${RSS_CONF:-/app/rss.yaml}"
TOPIC=$(python3 - "$CONF" <<'PY'
import sys,yaml
try:print((yaml.safe_load(open(sys.argv[1])) or {}).get("topic","brock-live-feed"))
except:print("brock-live-feed")
PY
)
TS=$(date '+%F %T');HOST=$(hostname)
curl -sS -H "Title: AI Watcher Heartbeat" -d "Alive @ $TS on $HOST" "https://ntfy.sh/$TOPIC" >/dev/null || true
echo "heartbeat sent → $TOPIC | $TS"
