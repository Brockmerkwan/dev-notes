#!/usr/bin/env zsh
set -euo pipefail
cd ~/Projects/devnotes

cp README.md README.bak.$(date +%Y%m%d_%H%M%S)

# remove the stray "paste exact block..." placeholder and fix double blank lines
awk '!/paste exact block above here/ { if(!(NF==0 && last_empty)){print}; last_empty=(NF==0) }' README.md > README.fixed

mv README.fixed README.md
git add README.md
git commit -m "docs(readme): remove leftover placeholder + spacing cleanup"
git push
