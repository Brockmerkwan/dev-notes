#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"
echo "🧩 Adjusting entrypoint logic for zsh compatibility..."

# Move progress loader above compatibility check and silence warning on zsh
awk '
/^set -e/ {
  print $0
  print "source \"$HOME/Projects/devnotes/tools/ux_progress.sh\""
  next
}
/Incompatible shell/ {
  print "if [[ $SHELL == *zsh* ]]; then"
  print "  echo \"✅ zsh environment detected — proceeding normally.\""
  print "else"
  print "  echo \"⚠️ Incompatible shell or old Bash detected.\""
  print "  echo \"   → Use ./core.sh instead of bash core.sh for full compatibility.\""
  print "fi"
  next
}
{print}
' "$target" > "${target}.patched"

mv "${target}.patched" "$target"
chmod +x "$target"

if zsh -n "$target"; then
  echo "✅ Syntax verified"
else
  echo "⚠️ Syntax error — check manually"
fi
