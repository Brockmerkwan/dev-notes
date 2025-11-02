#!/usr/bin/env zsh
set -euo pipefail
t="$HOME/Projects/devnotes/core.sh"
b="${t}.bak.$(date +%F_%H-%M-%S)"
cp "$t" "$b"
echo "🧠 Rebuilding core.sh header safely..."

# Strip first 30 lines (where damage usually sits)
tail -n +31 "$b" > "${t}.body"

cat > "$t" <<'HDR'
#!/usr/bin/env zsh
set -euo pipefail
# --- Core Boot Header (rebuilt) ---
function start_progress() {
  local msg="$1"; echo "⏳ $msg ..."
}
function stop_progress() {
  local msg="$1"; echo "✅ $msg (done)"
}
start_progress "Core Boot"
# -----------------------------------
HDR

cat "${t}.body" >> "$t"
echo 'stop_progress "Core Boot"' >> "$t"
rm "${t}.body"

if zsh -n "$t"; then
  echo "✅ Header rebuilt & syntax valid"
else
  echo "⚠️ Still invalid — check $b for manual diff"
fi
