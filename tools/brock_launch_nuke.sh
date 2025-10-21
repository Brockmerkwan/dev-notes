#!/usr/bin/env bash
# POSIX-friendly: no mapfile/shopt; works with macOS bash 3.2 or zsh invoking bash
set -euo pipefail

QUAR="$HOME/.local/state/disabled-plists"
DOM="gui/$(id -u)"
mkdir -p "$QUAR"

plist_read() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }
bootout()    { launchctl bootout "$DOM" "$1" 2>/dev/null || launchctl unload "$1" 2>/dev/null || true; }

echo ">> Scanning ~/Library/LaunchAgents for com.brock.*"
FOUND_CNT=0
FOUND_LIST=""

# Iterate using plain newlines (safe enough for plist paths)
find "$HOME/Library/LaunchAgents" -type f -name '*.plist' 2>/dev/null | while IFS= read -r P; do
  [ -f "$P" ] || continue
  LBL="$(plist_read "$P" Label)"
  case "$LBL" in
    com.brock.*)
      echo "   found: $LBL ($P)"
      FOUND_CNT=$((FOUND_CNT+1))
      FOUND_LIST="${FOUND_LIST}${P}"$'\n'
      ;;
  esac
done

# Re-run loop using the captured list (because subshell loses vars on macOS /bin/sh)
if [ -n "$FOUND_LIST" ]; then
  echo ">> Disabling + quarantining plists..."
  printf "%s" "$FOUND_LIST" | while IFS= read -r P; do
    [ -n "$P" ] || continue
    LBL="$(plist_read "$P" Label)"; [ -n "$LBL" ] || LBL="$(basename "${P%.plist}")"
    echo " - $LBL ($P)"
    bootout "$P"
    mv "$P" "$QUAR/$(basename "$P").$(date +%Y%m%d-%H%M%S)"
  done
else
  echo "No com.brock.* plists found."
fi

echo ">> Killing stray processes (aiwatcher/dashboard)…"
pkill -f "/Projects/devnotes/tools/aiwatcher"  >/dev/null 2>&1 || true
pkill -f "dashboard_server"                    >/dev/null 2>&1 || true
pkill -f "tools/aiwatcher.py"                  >/dev/null 2>&1 || true
pkill -f "tools/aiwatcher.sh"                  >/dev/null 2>&1 || true

echo ">> Verify:"
echo "launchctl (expect none):"
launchctl list | egrep 'com\.brock' || echo "  OK: no com.brock agents listed"
echo "ps (expect none):"
ps aux | egrep 'aiwatcher|dashboard_server' | egrep -v egrep || echo "  OK: no aiwatcher/dashboard processes"
echo "Quarantined to: $QUAR"
