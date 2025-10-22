#!/usr/bin/env zsh
set -euo pipefail

cd ~/Projects/devnotes
cp README.md README.bak.$(date +%Y%m%d_%H%M%S)

# Force-close unbalanced code fences and append clean footer
awk '
BEGIN { in_code=0 }
/^```bash/ { in_code=1; print; next }
/^```$/ { in_code=0; print; next }
/^## 📊 Repository Insights/ && in_code { print "```"; in_code=0 }
{ print }
END {
  if (in_code) print "```"
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
git commit -m "fix(readme): close code fences + restore footer rendering"
git push
