#!/usr/bin/env zsh
set -euo pipefail

cp README.md README.bak.$(date +%Y%m%d_%H%M%S)
awk '
  BEGIN { in_code=0 }
  /^```bash/ { in_code=1; print; next }
  /^```$/ { in_code=0; print; next }
  /^## 📊 Repository Insights/ && in_code { print "```"; in_code=0 }
  { print }
  END { if(in_code) print "```" }
' README.md > README.fixed

mv README.fixed README.md
git add README.md
git commit -m "fix(readme): ensure all code blocks close cleanly for GitHub renderer"
git push
