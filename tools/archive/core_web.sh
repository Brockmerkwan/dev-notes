#!/usr/bin/env bash
set -euo pipefail
PORT="${CORE_DASH_PORT:-7780}"
STATE="$HOME/.local/state/brock_core"
OUT="$STATE/dashboard_http.out"
ERR="$STATE/dashboard_http.err"
PY="$HOME/Projects/devnotes/tools/core_dash_web.py"

start(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; nohup "$PY" >>"$OUT" 2>>"$ERR" & sleep 0.5; echo "started on :$PORT"; }
stop(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; echo "stopped"; }
status(){ pgrep -fl core_dash_web.py >/dev/null && { echo "RUNNING on :$PORT"; } || { echo "STOPPED"; }; }
serve(){ exec "$PY"; }

case "${1-}" in
  --start) start ;;
  --stop) stop ;;
  --status) status ;;
  --serve) serve ;;
  *) echo "usage: $0 --start|--stop|--status|--serve";;
esac
