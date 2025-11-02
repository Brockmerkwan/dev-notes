#!/usr/bin/env zsh
set -euo pipefail

f="README.md"
cp "$f" "$f.bak.$(date +%Y%m%d_%H%M%S)"

# Step 1: Normalize Quick Usage into code fence
awk '
BEGIN { in_usage=0 }
{
  if ($0 ~ /^🚀 Quick Usage/) {
    print $0; print "```bash"; in_usage=1; next
  }
  if (in_usage && $0 ~ /^## 📊 Repository Insights/) {
    print "```"; in_usage=0
  }
  if (in_usage) {
    gsub(/[#][ ]?/, "# ", $0)
    gsub(/;/, ";\n", $0)
  }
  if ($0 ~ /&lt;div align="center"&gt;/ || $0 ~ /💠 \*\*Brock Core OS/) next
  if ($0 ~ /Built with ❤️/ || $0 ~ /© 2025 Brock/) next
  print
}
END {
  print ""
  print "---"
  print "<div align=\"center\">"
  print "💠 **Brock Core OS** — DevOps & Automation Playground  "
  print "<sub>Built with ❤️ using Zsh · macOS · GitHub Automation · AI Tooling</sub>  "
  print "<sup>© 2025 Brock Merkwan · MIT License · All systems operational</sup>"
  print "</div>"
}' "$f" > "$f.fixed"

mv "$f.fixed" "$f"
git add "$f"
git commit -m "docs(readme): cleanup quick-usage + unified footer"
git push
