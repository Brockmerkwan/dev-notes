#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"
echo "🧩 Injecting zsh-safe progress hooks into $target"

# Insert loader at top if missing
grep -q "ux_progress.sh" "$target" || \
  sed -i '' '1i\
source "$HOME/Projects/devnotes/tools/ux_progress.sh"
' "$target"

# Purge any old spinner/progress lines
sed -i '' '/start_progress/d;/stop_progress/d;/start_spinner/d;/stop_spinner/d' "$target"

# Use brace counter to insert stop lines only at valid end braces
awk '
function inject(name) {print "  start_progress \"" name "\""; stack[name]=1}
function stop() {for (n in stack){print "  stop_progress \"" n "\""; delete stack[n]}}
/^health_check\(\)/ {print; inject("Health Check"); next}
/^devnotes_sync\(\)/ {print; inject("DevNotes Sync"); next}
/^downloads_tidy_now\(\)/ {print; inject("Downloads Tidy"); next}
/^ollama_build_model\(\)/ {print; inject("Ollama Build"); next}
/^install_tidy_launchagent\(\)/ {print; inject("Install LaunchAgent"); next}
/^}/ {stop(); print; next}
{print}
' "$target" > "${target}.patched"

mv "${target}.patched" "$target"
chmod +x "$target"

if zsh -n "$target"; then
  echo "✅ Syntax verified"
else
  echo "⚠️ Syntax error — check manually"
fi
