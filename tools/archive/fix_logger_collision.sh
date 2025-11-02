#!/usr/bin/env zsh
set -euo pipefail
t="$HOME/Projects/devnotes/core.sh"
b="${t}.bak.$(date +%F_%H-%M-%S)"
cp "$t" "$b"
echo "🩹 Fixing macOS 'log' command collision..."

# Inject new logger if missing
if ! grep -q "brock_log()" "$t"; then
  cat <<'EOL' | cat - "$t" > "${t}.tmp" && mv "${t}.tmp" "$t"
brock_log() {
  local msg="$*"
  echo "[$(date +%H:%M:%S)] $msg"
}
EOL
fi

# Replace all references to "log " or "log:" with "brock_log "
perl -pi -e 's/\blog:/: /g' "$t"
perl -pi -e 's/\bhealth_check:log:/brock_log/g' "$t"
perl -pi -e 's/\becho log:/brock_log/g' "$t"
perl -pi -e 's/\blog /brock_log /g' "$t"
perl -pi -e 's/\blog:/brock_log /g' "$t"

zsh -n "$t" && echo "✅ Syntax valid" || echo "⚠️ Syntax check failed — see $b"
