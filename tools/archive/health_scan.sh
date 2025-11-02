#!/usr/bin/env zsh
set -euo pipefail
STATE_DIR="$HOME/.local/state"
LOG="$STATE_DIR/health_scan.log"
mkdir -p "$STATE_DIR"

echo "== $(date '+%F %T') health_scan ==" | tee -a "$LOG"

# 🔍 1. Syntax check all shell scripts
echo "[Syntax check]" | tee -a "$LOG"
find ~/Projects/devnotes -type f -name "*.sh" -exec bash -n {} \; && echo "✅ syntax clean" | tee -a "$LOG"

# 🔐 2. Permission audit
echo "[Permission check]" | tee -a "$LOG"
find ~/Projects/devnotes -type f -name "*.sh" ! -perm 755 -print -exec chmod 755 {} \; | tee -a "$LOG"

# 🧭 3. LaunchAgents status
echo "[LaunchAgents]" | tee -a "$LOG"
launchctl list | egrep "logsentinel.daily|downloads.tidy.weekly|archive.compactor.monthly|maintenance.overview.daily" | tee -a "$LOG" || echo "⚠️ No LaunchAgents found" | tee -a "$LOG"

# 🧹 4. Log size check
echo "[Log sizes]" | tee -a "$LOG"
find "$STATE_DIR" -type f -name "*.log" -exec du -h {} + | tee -a "$LOG"

echo "✅ health_scan complete" | tee -a "$LOG"
