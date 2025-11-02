#!/usr/bin/env bash
# aiwatcherctl.sh — one-file manager for AI Watcher (bash-based watcher)
# Controls tools/aiwatcher.sh (start/stop/restart/status/logs + enable/disable LaunchAgent)
# Idempotent; logs -> ~/.local/state/aiwatcher.log; supports --dry-run; menu UI.
set -euo pipefail

# ---------- Config (override via env) ----------
NAME="${NAME:-aiwatcher}"
BASE_DIR="${BASE_DIR:-$HOME/Projects/devnotes}"
WATCHER="${WATCHER:-$BASE_DIR/tools/aiwatcher.sh}" # your existing watcher
SHELL_BIN="${SHELL_BIN:-/bin/bash}"                 # used by LaunchAgent
LOG_DIR="${LOG_DIR:-$HOME/.local/state}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/${NAME}.log}"
PLIST="${PLIST:-$HOME/Library/LaunchAgents/com.brock.${NAME}.plist}"
INSTALL_PATH="${INSTALL_PATH:-/usr/local/bin/aiwatcherctl}"
DRY_RUN="${DRY_RUN:-0}"

# ---------- Helpers ----------
say(){ printf '%s\n' "$*"; }
hr(){ printf '%*s\n' "$(tput cols 2>/dev/null || echo 60)" | tr ' ' '-'; }
exists(){ command -v "$1" >/dev/null 2>&1; }
pidof_watcher(){ pgrep -f "$WATCHER" || true; }   # loose but reliable
run(){ if [[ "$DRY_RUN" = "1" ]]; then say "[dry-run] $*"; else eval "$@"; fi; }
need(){ for b in "$@"; do exists "$b" || { say "Missing binary: $b"; exit 1; }; done; }

usage(){
  cat <<USAGE
Usage: $(basename "$0") [start|stop|restart|status|logs|enable|disable|install|uninstall|menu] [--dry-run]
Env: NAME BASE_DIR WATCHER SHELL_BIN LOG_DIR LOG_FILE PLIST INSTALL_PATH DRY_RUN
USAGE
}

parse_flags(){
  local out=()
  for a in "$@"; do case "$a" in --dry-run) DRY_RUN=1;; *) out+=("$a");; esac; done
  ARGS=("${out[@]}")
}

preflight(){
  mkdir -p "$LOG_DIR"
  [[ -f "$WATCHER" && -x "$WATCHER" ]] || [[ -f "$WATCHER" ]] || say "Note: $WATCHER not executable; will run via bash."
  [[ -f "$WATCHER" ]] || { say "Watcher not found: $WATCHER"; exit 1; }
}

# ---------- Actions ----------
start(){
  preflight
  local p; p="$(pidof_watcher)"
  if [[ -n "$p" ]]; then say "$NAME already running (PID $p)"; return 0; fi
  say "Starting $NAME (daemon)…"
  # Prefer watcher --daemon if it exists; else background loop via our shell
  if grep -q -- '--daemon' "$WATCHER" 2>/dev/null; then
    run "nohup \"$SHELL_BIN\" \"$WATCHER\" --daemon >>\"$LOG_FILE\" 2>&1 &"
  else
    # Fallback: run once every 5m
    run "nohup \"$SHELL_BIN\" -c 'while true; do \"$SHELL_BIN\" \"$WATCHER\" --once >>\"$LOG_FILE\" 2>&1; sleep 300; done' &"
  fi
  sleep 0.6; status
}

stop(){
  local p; p="$(pidof_watcher)"
  if [[ -z "$p" ]]; then say "$NAME not running."; return 0; fi
  say "Stopping $NAME (PID $p)…"
  run "pkill -f \"$WATCHER\" || true"
  sleep 0.6; status
}

restart(){ stop; sleep 0.5; start; }

status(){
  local p; p="$(pidof_watcher)"
  if [[ -n "$p" ]]; then say "🟢 $NAME running (PID $p)"; else say "🔴 $NAME stopped"; fi
}

logs(){ mkdir -p "$LOG_DIR"; touch "$LOG_FILE"; say "Tailing $LOG_FILE (Ctrl-C to exit)…"; hr; tail -n 50 -f "$LOG_FILE"; }

enable(){
  preflight
  say "Creating LaunchAgent: $PLIST"
  run "mkdir -p \"$(dirname "$PLIST")\""
  local tmp; tmp="$(mktemp)"
  cat >"$tmp" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0"><dict>
  <key>Label</key><string>com.brock.${NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${SHELL_BIN}</string>
    <string>${WATCHER}</string>
    <string>--daemon</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${LOG_FILE}</string>
  <key>StandardErrorPath</key><string>${LOG_FILE}</string>
</dict></plist>
XML
  run "mv \"$tmp\" \"$PLIST\""
  run "launchctl unload \"$PLIST\" 2>/dev/null || true"
  run "launchctl load \"$PLIST\""
  sleep 0.6; status
}

disable(){
  say "Unloading & removing LaunchAgent…"
  run "launchctl unload \"$PLIST\" 2>/dev/null || true"
  run "rm -f \"$PLIST\""
  status
}

install_self(){
  need install
  say "Installing CLI -> $INSTALL_PATH"
  run "sudo install -m 0755 \"$0\" \"$INSTALL_PATH\""
  say "OK. Try: $INSTALL_PATH menu"
}

uninstall_self(){
  if [[ -f "$INSTALL_PATH" ]]; then
    say "Removing $INSTALL_PATH"; run "sudo rm -f \"$INSTALL_PATH\""
  else
    say "Nothing to remove at $INSTALL_PATH"
  fi
}

menu(){
  while :; do
    hr; say "AI Watcher Control — $NAME"
    say "Watcher: $WATCHER"; say "Logs: $LOG_FILE"; status; hr
    cat <<M
1) Start
2) Stop
3) Restart
4) Status
5) Logs
6) Enable (login auto-start)
7) Disable (remove auto-start)
8) Install CLI (/usr/local/bin/aiwatcherctl)
9) Uninstall CLI
0) Exit
M
    read -rp "Select: " c
    case "${c:-}" in
      1) start ;; 2) stop ;; 3) restart ;; 4) status ;; 5) logs ;;
      6) enable ;; 7) disable ;; 8) install_self ;; 9) uninstall_self ;;
      0) break ;; *) say "Invalid";;
    esac
  done
}

# ---------- Dispatcher (safe; supports --dry-run anywhere) ----------
main(){
  ARGS=(); parse_flags "$@"
  local cmd="${ARGS[0]:-menu}"
  [[ "${#ARGS[@]}" -gt 0 ]] && ARGS=("${ARGS[@]:1}")
  case "$cmd" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    logs) logs ;;
    enable) enable ;;
    disable) disable ;;
    install) install_self ;;
    uninstall) uninstall_self ;;
    menu) menu ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}
main "$@"
