#!/bin/zsh
# Automation Suite: backup.sh
# Purpose: Archive repo (excluding .git) to backups/ with timestamp, keep last 10 archives.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
if [[ -d "$SCRIPT_DIR/.git" ]]; then
  REPO_DIR="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/../.git" ]]; then
  REPO_DIR="$SCRIPT_DIR/.."
else
  echo "❌ Cannot locate .git. Put this script inside your Git repo (e.g., repo/scripts/backup.sh)."
  exit 1
fi
cd "$REPO_DIR"

mkdir -p backups
TS="$(date '+%Y-%m-%d_%H-%M-%S')"
NAME="$(basename "$REPO_DIR")_${TS}.tar.gz"

echo "→ Creating archive: backups/$NAME"
# Exclude .git, backups themselves, and large caches
tar --exclude='.git' --exclude='backups' --exclude='*.tar.gz' -czf "backups/$NAME" .

echo "→ Listing archives (newest first):"
ls -1t backups/*.tar.gz | nl

# Keep last 10
COUNT=$(ls -1t backups/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COUNT" -gt 10 ]]; then
  echo "→ Pruning old archives (keeping last 10)"
  ls -1t backups/*.tar.gz | tail -n +11 | xargs rm -f
fi

echo "✅ Backup complete: backups/$NAME"
