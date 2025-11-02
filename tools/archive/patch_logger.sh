#!/usr/bin/env zsh
set -euo pipefail
t="$HOME/Projects/devnotes/core.sh"
b="${t}.bak.$(date +%F_%H-%M-%S)"
cp "$t" "$b"
echo "🩹 Injecting unified logger and cleaning up bad 'log:' syntax..."

# Inject at top if missing
if ! grep -q "log_msg()" "$t"; then
  cat <<'EOL' | cat - "$t" > "${t}.tmp" && mv "${t}.tmp" "$t"
log_msg() {
  local msg="$*"
  echo "[$(date +%H:%M:%S)] $msg"
}
EOL
fi

# Replace 'log:' prefixes with 'log_msg'
perl -pi -e 's/\blog:/: /g' "$t"
perl -pi -e 's/\bhealth_check:log:/log_msg/g' "$t"
perl -pi -e 's/\becho log:/log_msg/g' "$t"
perl -pi -e 's/\blog:/log_msg/g' "$t"

zsh -n "$t" && echo "✅ Syntax valid" || echo "⚠️ Syntax check failed — see $b"
