#!/usr/bin/env bash
set -euo pipefail

CONF="${RSS_CONF:-/app/rss.yaml}"

topic_from_conf() {
  python3 - "$CONF" <<'PY'
import sys, yaml
p = sys.argv[1]
try:
    with open(p) as f:
        cfg = yaml.safe_load(f) or {}
    print(cfg.get("topic","brock-live-feed"))
except Exception:
    print("brock-live-feed")
PY
}

TOPIC="$(topic_from_conf)"
HOST="$(hostname 2>/dev/null || echo unknown)"
TS="$(date '+%Y-%m-%d %H:%M:%S')"
STATUS_LINE="(container) ok"

curl -sS -H "Title: AI Watcher Heartbeat" -H "Priority: 3" \
  --data-binary "Alive @ $TS on $HOST
$STATUS_LINE" "https://ntfy.sh/${TOPIC}" >/dev/null || true

echo "heartbeat sent → $TOPIC | $TS | $STATUS_LINE"
