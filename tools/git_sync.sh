#!/usr/bin/env zsh
set -euo pipefail
STATE_DIR="$HOME/.local/state"
LOG="$STATE_DIR/git_sync.log"
mkdir -p "$STATE_DIR"

echo "== $(date '+%F %T') git_sync ==" | tee -a "$LOG"
bash -n core.sh && echo "syntax OK" | tee -a "$LOG"
git add -A
git commit -m "auto(sync): maintenance + verified core.sh syntax" || echo "no changes"
git push origin main | tee -a "$LOG"
echo "✅ sync complete" | tee -a "$LOG"
