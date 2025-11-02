#!/usr/bin/env bash
# macOS-safe bulk disable for com.brock.* LaunchAgents (no subshell var loss)
set -euo pipefail

USER_LIB="$HOME/Library/LaunchAgents"
QUAR="$HOME/.local/state/disabled-plists"
DOM="gui/$(id -u)"
TMP_LIST="$(mktemp)"
mkdir -p "$QUAR"

plist_read(){ /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }
bootout_path(){ launchctl bootout "$DOM" "$1" 2>/dev/null || launchctl unload "$1" 2>/dev/null || true; }
bootout_label(){ launchctl bootout "$DOM" "$1" 2>/dev/null || true; }

echo ">> Scanning $USER_LIB for com.brock.*"
# Build candidate list WITHOUT a pipeline (avoids subshell)
IFS='
'
for P in $(find "$USER_LIB" -type f -name '*.plist' 2>/dev/null); do
  [ -f "$P" ] || continue
  LBL="$(plist_read "$P" Label)"
  case "$LBL" in
    com.brock.*)
      echo "   found: $LBL  ($P)"
      printf "%s\t%s\n" "$LBL" "$P" >>"$TMP_LIST"
      ;;
  esac
done

if [ ! -s "$TMP_LIST" ]; then
  echo "No com.brock.* plists found."
else
  CNT=$(wc -l < "$TMP_LIST" | tr -d ' ')
  echo ">> Disabling + quarantining $CNT plists…"
  # Read back the list now (no subshell)
  while IFS=$'\t' read -r LBL P; do
    [ -n "$LBL" ] || continue
    echo " - $LBL ($P)"
    # Bootout by label first (more reliable on newer macOS), then by path
    bootout_label "$LBL"
    bootout_path  "$P"
    # Move plist to quarantine (keeps original name + timestamp)
    TS="$(date +%Y%m%d-%H%M%S)"
    mv "$P" "$QUAR/$(basename "$P").$TS"
  done <"$TMP_LIST"
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
rm -f "$TMP_LIST"
