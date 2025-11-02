#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"

# Ensure progress module is sourced once at top
if ! grep -q "ux_progress.sh" "$target"; then
  echo "🧩 Injecting ux_progress loader..."
  awk 'NR==1{print "source \"$HOME/Projects/devnotes/tools/ux_progress.sh\""}1' "$target" > "${target}.patched"
  mv "${target}.patched" "$target"
fi

# Wrap main run sections with progress calls
awk '
/^health_check\(\)/,/^}/ {
  if ($0 ~ /^health_check\(\)/) {print $0 "\n  start_progress \"Health Check\""; next}
  if ($0 ~ /^}/) {print "  stop_progress \"Health Check\"\n" $0; next}
}
{print}
' "$target" > "${target}.tmp"

awk '
/^devnotes_sync\(\)/,/^}/ {
  if ($0 ~ /^devnotes_sync\(\)/) {print $0 "\n  start_progress \"DevNotes Sync\""; next}
  if ($0 ~ /^}/) {print "  stop_progress \"DevNotes Sync\"\n" $0; next}
}
{print}
' "${target}.tmp" > "${target}.patched"

mv "${target}.patched" "$target"
rm -f "${target}.tmp"

chmod +x "$target"
echo "✅ Patched: $target"
