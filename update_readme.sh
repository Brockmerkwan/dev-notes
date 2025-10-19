#!/bin/bash
# === update_readme.sh ===
# Refreshes the Living README metadata, injects updated docs, and pushes changes automatically.

set -e
REPO_DIR="$HOME/Projects/devnotes"
cd "$REPO_DIR" || exit

timestamp=$(date +"%Y-%m-%d %H:%M:%S")
commit_hash=$(git rev-parse --short HEAD)

# Update metadata timestamp and commit info
sed -i '' "s/^_Last updated:.*/_Last updated: ${timestamp}_/" README.md
sed -i '' "s/^_Current commit:.*/_Current commit:_ \`${commit_hash}\`/" README.md

# Auto-refresh Playbooks section
start_marker="<!--AUTO:PLAYBOOKS_START-->"
end_marker="<!--AUTO:PLAYBOOKS_END-->"

playbooks=$(find docs -type f \( -name '*.md' -o -name '*.pdf' \) -exec basename {} \; | sort | awk '{print "- [", $0, "](docs/" $0 ")"}' | sed 's/ \]/]/g')

awk -v repl="$playbooks" -v start="$start_marker" -v end="$end_marker" '
  $0 == start {print; print repl; skip=1; next}
  $0 == end {skip=0}
  !skip
' README.md > README.tmp && mv README.tmp README.md

# Commit and push
git add README.md
git commit -m "docs: auto-update living README (${timestamp})" || true
git push

echo "[update_readme] ✅ README updated and pushed."
