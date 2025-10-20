#!/usr/bin/env bash
# Brock Core OS — main menu (enhanced)
set -euo pipefail
SCRIPT="$(basename "${BASH_SOURCE[0]:-$0}")"
STATE_DIR="${HOME}/.local/state/brock_core"; mkdir -p "$STATE_DIR"
LOG="${STATE_DIR}/core.log"; log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
require(){ command -v "$1" >/dev/null 2>&1 || { log "ERR: missing dep: $1"; exit 1; }; }

PROJECT_DIR="${HOME}/Projects/devnotes"
PROMPT_FILE="${PROJECT_DIR}/system_prompts/brock_core_os_v3.md"

health(){ log "[health]"; echo "OS: $(sw_vers -productVersion 2>/dev/null || uname -a)"; df -h / | awk 'NR==1||NR==2'; vm_stat | awk '/free/ {print "Free RAM pages: "$3}'; }
sync(){ require git; cd "$PROJECT_DIR"; git fetch --all --prune; if ! git diff --quiet || ! git diff --cached --quiet; then git add -A; git commit -m "chore(sync): DevNotes auto-sync via core.sh"; git push; log "sync: pushed"; else log "sync: clean"; fi; }
prompt(){ [[ -s "$PROMPT_FILE" ]] && { echo "$PROMPT_FILE"; open -R "$PROMPT_FILE" 2>/dev/null || true; } || log "WARN: prompt missing"; }

aiwatch(){ "$PROJECT_DIR/tools/aiwatcher.sh" "${@:---once}"; }
dash(){ "$PROJECT_DIR/tools/core_dash.sh"; }

web_start(){ "$PROJECT_DIR/tools/core_web.sh" --start; }
web_stop(){ "$PROJECT_DIR/tools/core_web.sh" --stop; }
web_status(){ "$PROJECT_DIR/tools/core_web.sh" --status; open "http://localhost:${CORE_DASH_PORT:-7780}" 2>/dev/null || true; }

usage(){ cat <<USG
$SCRIPT — menu
  $SCRIPT                # interactive
  $SCRIPT --health
  $SCRIPT --sync
  $SCRIPT --prompt
  $SCRIPT --aiwatch [flags]
  $SCRIPT --dash
  $SCRIPT --web-start|--web-stop|--web-status
USG
}

menu(){
  PS3="Select: "
  select opt in \
    "Health Check" "Sync DevNotes" "Open Prompt" \
    "Run AI Watcher once" "Dashboard (CLI)" \
    "Web Dashboard START" "Web Dashboard STATUS" "Web Dashboard STOP" "Exit"
  do
    case "$REPLY" in
      1) health ;;
      2) sync ;;
      3) prompt ;;
      4) aiwatch --once ;;
      5) dash ;;
      6) web_start ;;
      7) web_status ;;
      8) web_stop ;;
      9) exit 0 ;;
      *) echo "Invalid";;
    esac
  done
}

case "${1-}" in
  --health) health ;;
  --sync) sync ;;
  --prompt) prompt ;;
  --aiwatch) shift || true; aiwatch "$@" ;;
  --dash) dash ;;
  --web-start) web_start ;;
  --web-stop) web_stop ;;
  --web-status) web_status ;;
  "" ) menu ;;
  * ) usage ;;
esac
