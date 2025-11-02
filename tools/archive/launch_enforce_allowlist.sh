#!/usr/bin/env bash
set -euo pipefail

# ALLOW only these com.brock.* labels (edit as needed)
ALLOW=(
  # com.brock.aiwatcher            # uncomment if you want it on login
)

DOM="gui/$(id -u)"
USER_LIB="$HOME/Library/LaunchAgents"
QUAR="$HOME/.local/state/disabled-plists"; mkdir -p "$QUAR"

in_allow() { local x="$1"; for a in "${ALLOW[@]}"; do [[ "$x" == "$a" ]] && return 0; done; return 1; }
plist_read(){ /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }

# Gather loaded labels
mapfile -t LOADED < <(launchctl list | awk '{print $3}' | grep '^com\.brock\.' || true)

# Disable anything not allowed, both loaded and present on disk
for LBL in "${LOADED[@]}"; do
  in_allow "$LBL" && continue
  echo ">> bootout: $LBL"
  launchctl bootout "$DOM" "$LBL" 2>/dev/null || launchctl remove "$LBL" 2>/dev/null || true
done

# Sweep plist files
find "$USER_LIB" -maxdepth 1 -type f -name 'com.brock.*.plist' 2>/dev/null | while IFS= read -r P; do
  LBL="$(plist_read "$P" Label)"; [[ -z "$LBL" ]] && LBL="$(basename "${P%.plist}")"
  in_allow "$LBL" && continue
  TS="$(date +%Y%m%d-%H%M%S)"
  echo ">> quarantine: $LBL ($P)"
  mv "$P" "$QUAR/$(basename "$P").$TS"
done

echo ">> verify"
launchctl list | egrep 'com\.brock' || echo "  OK: none loaded"
