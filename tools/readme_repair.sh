#!/usr/bin/env zsh
set -euo pipefail
cd ~/Projects/devnotes

tmp="README.fixed"

awk '
/^--- ## 📊 Repository Insights/ {
  # If no closing fence seen, add one before section divider
  if (prev_line !~ /^```$/) print "```"
}
{
  # Remove escaped footer remnants
  if ($0 ~ /&lt;div align="center"&gt;/) skip=1
  if (skip && $0 ~ /&lt;\/div&gt;/) { skip=0; next }
  if (skip) next
  print $0
  prev_line=$0
}
END {
  print ""
  print "---"
  print "<div align=\"center\">"
  print "💠 **Brock Core OS** — DevOps & Automation Playground  "
  print "<sub>Built with ❤️ using Zsh · macOS · GitHub Automation · AI Tooling</sub>  "
  print "<sup>© 2025 Brock Merkwan · MIT License · All systems operational</sup>"
  print "</div>"
}' README.md > "$tmp"

mv "$tmp" README.md
git add README.md
git commit -m "fix(readme): repair code fences + clean duplicate footer"
git push
