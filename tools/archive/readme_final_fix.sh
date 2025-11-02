#!/usr/bin/env zsh
set -euo pipefail

# Fix Quick Usage formatting and footer duplication
awk '
BEGIN { in_usage=0; skip=0 }
{
  # Detect start of Quick Usage section
  if ($0 ~ /^🚀 Quick Usage/) { print $0; print "```bash"; in_usage=1; next }

  # Detect next section and close code block
  if (in_usage && $0 ~ /^## 📊 Repository Insights/) {
    print "```"; in_usage=0
  }

  # Remove escaped footer junk
  if ($0 ~ /&lt;div align="center"&gt;/) { skip=1 }
  if (skip && $0 ~ /&lt;\/div&gt;/) { skip=0; next }
  if (skip) next

  print $0
}
END {
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
git commit -m "fix(readme): finalize code block + remove escaped footer"
git push
