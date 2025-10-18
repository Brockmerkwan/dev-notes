#!/bin/zsh
# Automation Suite: update.sh
# Purpose: Pull, stage, commit (if changes), push; log everything to daily_logs/
set -euo pipefail

# Resolve repo root as the parent of this script's directory (place scripts/ inside your repo).
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
# If this folder is directly in the repo, use SCRIPT_DIR; if in repo/scripts, use its parent.
if [[ -d "$SCRIPT_DIR/.git" ]]; then
  REPO_DIR="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/../.git" ]]; then
  REPO_DIR="$SCRIPT_DIR/.."
else
  echo "❌ Cannot locate .git. Put this script inside your Git repo (e.g., repo/scripts/update.sh)."
  exit 1
fi

cd "$REPO_DIR"

# Ensure log directory
mkdir -p daily_logs
LOG_FILE="daily_logs/$(date '+%F')_update.log"

{
  echo "=== UPDATE RUN $(date) ==="
  echo "Repo: $REPO_DIR"
  echo

  echo "→ git status (before)"
  git status -sb || true
  echo

  echo "→ git pull"
  git pull --ff-only || true
  echo

  echo "→ staging changes"
  git add -A

  echo "→ checking for diff"
  if git diff --cached --quiet; then
    echo "No staged changes; skipping commit."
  else
    MSG="auto: daily update $(date '+%F %T')"
    echo "→ committing: $MSG"
    git commit -m "$MSG"
  fi

  echo "→ pushing"
  git push || true

  echo
  echo "→ git status (after)"
  git status -sb || true
  echo "=== DONE $(date) ==="
} | tee -a "$LOG_FILE"

echo "✅ Update complete. Log: $LOG_FILE"
