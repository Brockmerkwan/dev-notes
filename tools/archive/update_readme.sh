#!/usr/bin/env bash
set -euo pipefail
echo "🧠 Updating README..."
STAMP=$(date '+%Y-%m-%d %H:%M:%S')
sed -i "" -e "s/^_Last updated:.*/_Last updated: ${STAMP}/" README.md 2>/dev/null || true
git add README.md
git commit -m "auto(readme): update timestamp ${STAMP}" || true
