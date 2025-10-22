#!/usr/bin/env zsh
set -euo pipefail

echo "💠 [$(date)] Starting Core Orchestrator"

# Detect repos (directories with .git folders)
REPOS=()
for dir in ~/Projects/*; do
  [[ -d "$dir/.git" ]] && REPOS+=("${dir:t}")
done

echo "🔍 Found ${#REPOS[@]} repositories:"
for repo in "${REPOS[@]}"; do
  echo " - $repo"
done

for repo in "${REPOS[@]}"; do
  echo "⚙️  Processing $repo"
  cd ~/Projects/$repo || { echo "❌ Skipping missing repo: $repo"; continue }
  
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git add -A
    git commit -m "auto(core): sync ${repo} via orchestrator $(date '+%Y-%m-%d %H:%M')" || true
    git push || true
  else
    echo "⚠️  Not a Git repo: $repo"
  fi
done

echo "✅ All repositories processed."
