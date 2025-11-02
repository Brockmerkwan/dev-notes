#!/usr/bin/env zsh
set -euo pipefail

cp README.md README.bak.$(date +%Y%m%d_%H%M%S)

# BSD awk: all `if` and regex blocks use braces
awk '
BEGIN { in_usage=0; skip=0 }
/^🚀 Quick Usage/ { print $0; print "```bash"; in_usage=1; next }
/^## 📊 Repository Insights/ {
  if (in_usage) { print "```"; in_usage=0 }
}

# detect &lt;div align lines safely
$0 ~ /&lt;div align/ { skip=1; next }
$0 ~ /&lt;\/div&gt;/ { skip=0; next }
{ if (skip) { next } }

# remove duplicate footer lines
/^💠 \*\*Brock Core OS/ { next }
/^Built with ❤️/ { next }
/^© 2025 Brock/ { next }

{ print }

END {
  if (in_usage) { print "```" }
  print ""
  print "---"
  print "<div align=\"center\">"
  print "💠 **Brock Core OS** — DevOps & Automation Playground  "
  print "<sub>Built with ❤️ using Zsh · macOS · GitHub Automation · AI Tooling</sub>  "
  print "<sup>© 2025 Brock Merkwan · MIT License · All systems operational</sup>"
  print "</div>"
}' README.md > README.fixed

mv README.fixed README.md
git add README.md
git commit -m "fix(readme): BSD-awk safe cleanup + proper footer"
git push
