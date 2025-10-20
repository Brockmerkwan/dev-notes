#!/usr/bin/env bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

CONF="${RSS_CONF:-$HOME/.brock/rss.yaml}"
PY="$HOME/.venvs/rss/bin/python3"

# Read topic from YAML using the venv python
TOPIC="$($PY - <<'PY'
import sys, yaml, os
conf = os.environ.get("CONF") or sys.argv[1] if len(sys.argv) > 1 else None
if not conf: 
    print("brock-live-feed"); raise SystemExit(0)
with open(conf, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f) or {}
print(cfg.get("topic", "brock-live-feed"))
PY
)"
: "${TOPIC:=brock-live-feed}"

HOST="$(scutil --get LocalHostName 2>/dev/null || hostname)"
TS="$(date '+%Y-%m-%d %H:%M:%S')"
STATUS="$("$HOME/Projects/devnotes/tools/local_ai/status_sysscan.sh" 2>/dev/null || echo 'sys-scan n/a')"

TITLE="AI Watcher Heartbeat"
BODY="Alive @ $TS on $HOST
$STATUS"

curl -sS \
  -H "Content-Type: text/plain; charset=utf-8" \
  -H "Title: ${TITLE}" \
  -H "Priority: 3" \
  --data-binary "$BODY" "https://ntfy.sh/${TOPIC}" >/dev/null

echo "heartbeat sent → $TOPIC | $TS | $STATUS"
