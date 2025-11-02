#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"
echo "🧹 Cleaning leftover echo lines + verifying progress hooks..."

# Remove legacy compatibility warning lines
sed -i '' '/Use .\/core.sh instead of bash core.sh/d' "$target"
sed -i '' '/Incompatible shell/d' "$target"

# Add startup progress indicator
if ! grep -q 'start_progress "Core Boot"' "$target"; then
  sed -i '' '2a\
start_progress "Core Boot"
' "$target"
  echo '\nstop_progress "Core Boot"' >> "$target"
fi

# Syntax check
if zsh -n "$target"; then
  echo "✅ Syntax verified, entrypoint cleaned"
else
  echo "⚠️ Syntax error — inspect $target"
fi
