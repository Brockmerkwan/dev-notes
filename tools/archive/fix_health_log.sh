#!/usr/bin/env zsh
set -euo pipefail
t="$HOME/Projects/devnotes/core.sh"
b="${t}.bak.$(date +%F_%H-%M-%S)"
cp "$t" "$b"
echo "🩹 Fixing health_check log quoting..."

# Replace any unquoted log arguments (common source of "too many arguments")
awk '
/^health_check\(\)/,/^}/ {
  if ($0 ~ /log:/ && $0 !~ /"/) {
    gsub(/log:[[:space:]]*/, "log:\"", $0)
    $0 = $0 "\""
  }
}
{print}
' "$b" > "$t"

if zsh -n "$t"; then
  echo "✅ Syntax valid"
else
  echo "⚠️ Syntax error — check $b"
fi
