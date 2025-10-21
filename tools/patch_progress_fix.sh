#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"

echo "🩹 Re-injecting progress hooks (zsh-safe)..."

# 1️⃣ Ensure loader is sourced near top
if ! grep -q "ux_progress.sh" "$target"; then
  sed -i '' '1i\
source "$HOME/Projects/devnotes/tools/ux_progress.sh"
' "$target"
fi

# 2️⃣ Remove any old spinner lines
sed -i '' '/start_spinner/d;/stop_spinner/d' "$target"

# 3️⃣ Add progress start/stop around known blocks
awk '
/^health_check\(\)/ {print; print "  start_progress \"Health Check\""; next}
/^devnotes_sync\(\)/ {print; print "  start_progress \"DevNotes Sync\""; next}
/^downloads_tidy_now\(\)/ {print; print "  start_progress \"Downloads Tidy\""; next}
/^ollama_build_model\(\)/ {print; print "  start_progress \"Ollama Build\""; next}
/^install_tidy_launchagent\(\)/ {print; print "  start_progress \"Install LaunchAgent\""; next}
/^}/ {
  print "  stop_progress \"$FUNCNAME\""
  next
}
{print}
' "$target" > "${target}.tmp"

mv "${target}.tmp" "$target"
chmod +x "$target"

# 4️⃣ Syntax verify
if zsh -n "$target"; then
  echo "✅ Syntax OK: core.sh"
else
  echo "⚠️ Syntax error — check $target"
fi
