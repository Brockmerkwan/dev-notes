#!/usr/bin/env bash
# Brock Core OS — main menu
set -euo pipefail

STATE_DIR="${HOME}/.local/state/brock_core"
LOG="${STATE_DIR}/core.log"
mkdir -p "${STATE_DIR}"

log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

require(){
  command -v "$1" >/dev/null 2>&1 || { log "ERR: missing dep: $1"; return 1; }
}

PROJECT_DIR="${HOME}/Projects/devnotes"
PROMPT_FILE="${PROJECT_DIR}/system_prompts/brock_core_os_v3.md"
OLLAMA_DIR="${PROJECT_DIR}/local_ai/ollama"
MODEFILE="${OLLAMA_DIR}/Modelfile"

health_check(){
  log "== Health Check =="
  echo "• OS: $(sw_vers -productVersion 2>/dev/null || uname -a)"
  echo "• Shell: $SHELL"
  echo "• Disk (/): $(df -h / | awk 'NR==2{print $4" free"}')"
  echo "• RAM free: $(vm_stat 2>/dev/null | awk '/free/ {print $3}' | sed 's/\.//' ) pages"
  echo "• Network ping: $(ping -c1 -t2 1.1.1.1 >/dev/null 2>&1 && echo OK || echo FAIL)"
  (command -v brew >/dev/null && echo "• brew: $(brew --version | head -n1)" || echo "• brew: not installed") || true
  (command -v git >/dev/null && echo "• git: $(git --version)" || echo "• git: not installed") || true
  if command -v ollama >/dev/null 2>&1; then
    echo "• ollama: $(ollama --version 2>/dev/null || echo present)"
    (ollama ps || true)
  else
    echo "• ollama: not installed"
  fi
  log "OK health_check done"
}

devnotes_sync(){
  log "== DevNotes Sync =="
  require git || return 1
  cd "$PROJECT_DIR"
  git fetch --all --prune
  git status -sb
  # Auto-add trivial changes if any staged/unstaged present
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "chore(sync): DevNotes auto-sync via core.sh"
    git push
    log "Pushed changes"
  else
    log "No changes to push"
  fi
}

open_prompt_path(){
  log "== System Prompt Path =="
  if [[ -s "$PROMPT_FILE" ]]; then
    echo "$PROMPT_FILE"
    # macOS: reveal in Finder (non-fatal if unavailable)
    (open -R "$PROMPT_FILE" 2>/dev/null || true)
  else
    log "WARN: prompt file missing: $PROMPT_FILE"
  fi
}

ollama_build_model(){
  log "== Build Ollama model: brock-core:latest =="
  require ollama || return 1
  mkdir -p "$OLLAMA_DIR"
  if [[ ! -s "$MODEFILE" ]]; then
    cat > "$MODEFILE" <<'EOM'
FROM mistral:latest
SYSTEM """
(See ~/Projects/devnotes/system_prompts/brock_core_os_v3.md)
Paste the compact v3 prompt here if you want a self-contained Modelfile.
"""
PARAMETER temperature 0.4
EOM
    log "Created Modelfile scaffold at $MODEFILE"
  fi
  ollama create brock-core:latest -f "$MODEFILE"
  echo "Test:"
  ollama run brock-core:latest "Say READY if system prompt is active."
  log "OK ollama build"
}

downloads_tidy_now(){
  log "== Downloads Tidy Now =="
  SRC="${HOME}/Downloads"
  DST="${HOME}/Archive/Downloads/$(date +%Y-%m)"
  mkdir -p "$DST"
  # move non-hidden files older than 2 days; skip .dmg currently in use
  find "$SRC" -maxdepth 1 -type f -mtime +2 -not -name ".*" -print -exec mv -n "{}" "$DST"/ \;
  log "Moved old files to $DST"
}

install_tidy_launchagent(){
  log "== Install LaunchAgent: weekly downloads tidy =="
  PL="$HOME/Library/LaunchAgents/com.brock.downloads_tidy.plist"
  mkdir -p "$(dirname "$PL")"
  cat > "$PL" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0">
 <dict>
  <key>Label</key><string>com.brock.downloads_tidy</string>
  <key>ProgramArguments</key>
  <array>
   <string>/bin/bash</string>
   <string>-lc</string>
   <string>~/Projects/devnotes/core.sh --tidy-now</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>7</integer> <!-- Sunday -->
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>${HOME}/.local/state/brock_core/downloads_tidy.out</string>
  <key>StandardErrorPath</key><string>${HOME}/.local/state/brock_core/downloads_tidy.err</string>
  <key>RunAtLoad</key><true/>
 </dict>
</plist>
PLIST
  launchctl unload "$PL" 2>/dev/null || true
  launchctl load "$PL"
  launchctl list | grep -q com.brock.downloads_tidy && log "Agent loaded" || log "WARN: Agent not listed"
}

usage(){
  cat <<USG
Brock Core OS — menu
Usage:
  $0                 # interactive menu
  $0 --health        # run health check
  $0 --sync          # git sync DevNotes
  $0 --prompt        # reveal prompt file
  $0 --ollama-build  # build brock-core model
  $0 --tidy-now      # run downloads tidy once
  $0 --install-tidy  # install weekly LaunchAgent
USG
}

menu(){
  PS3="Select: "
  select opt in \
    "Run Health Check" \
    "Sync DevNotes" \
    "Open System Prompt path" \
    "Build Ollama model (brock-core)" \
    "Tidy Downloads now" \
    "Install weekly tidy LaunchAgent" \
    "Exit"
  do
    case "$REPLY" in
      1) health_check ;;
      2) devnotes_sync ;;
      3) open_prompt_path ;;
      4) ollama_build_model ;;
      5) downloads_tidy_now ;;
      6) install_tidy_launchagent ;;
      7) exit 0 ;;
      *) echo "Invalid";;
    esac
  done
}

# CLI switchboard
case "${1-}" in
  --health) health_check ;;
  --sync) devnotes_sync ;;
  --prompt) open_prompt_path ;;
  --ollama-build) ollama_build_model ;;
  --tidy-now) downloads_tidy_now ;;
  --install-tidy) install_tidy_launchagent ;;
  "" ) menu ;;
  * ) usage ;;
esac

