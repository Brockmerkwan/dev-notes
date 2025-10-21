#!/usr/bin/env zsh
set -euo pipefail
cd ~/Projects/devnotes

tmp="README.tmp"
awk '
BEGIN {in_code=0}
{
  # detect code fence region
  if ($0 ~ /^```/) {
    in_code = !in_code
  }
  print $0
}
END {
  if (in_code) print "```"
  print "\n---"
  print "<div align=\"center\">"
  print "💠 **Brock Core OS** — DevOps & Automation Playground  "
  print "<sub>Built with ❤️ using Zsh · macOS · GitHub Automation · AI Tooling</sub>  "
  print "<sup>© 2025 Brock Merkwan · MIT License · All systems operational</sup>"
  print "</div>"
}' README.md > "$tmp"

mv "$tmp" README.md
git add README.md
git commit -m "docs(readme): reposition footer after code block + clean layout"
git push
