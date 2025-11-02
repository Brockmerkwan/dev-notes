#!/usr/bin/env zsh
set -euo pipefail
target="$HOME/Projects/devnotes/core.sh"
backup="${target}.bak.$(date +%F_%H-%M-%S)"
cp "$target" "$backup"
echo "🧩 Repairing syntax + injecting local progress wrapper..."

# 1️⃣ Remove previous broken insertions
sed -i '' '/start_progress "Core Boot"/d' "$target" || true
sed -i '' '/stop_progress "Core Boot"/d' "$target" || true
sed -i '' '/Incompatible shell/d' "$target" || true
sed -i '' '/Use .\/core.sh instead of bash core.sh/d' "$target" || true

# 2️⃣ Inject minimal progress functions at top if missing
if ! grep -q 'function start_progress' "$target"; then
cat <<'FN' | cat - "$target" > "${target}.tmp" && mv "${target}.tmp" "$target"
# --- Minimal local progress functions ---
function start_progress() {
  local msg="$1"; echo "⏳ $msg ..."
}
function stop_progress() {
  local msg="$1"; echo "✅ $msg (done)"
}
# ---------------------------------------
FN
fi

# 3️⃣ Inject call safely after shebang
awk '
NR==2 && $0 !~ /start_progress/ {
  print "start_progress \"Core Boot\""
  print; next
}
NR>2 {print}
' "$target" > "${target}.tmp" && mv "${target}.tmp" "$target"
echo 'stop_progress "Core Boot"' >> "$target"

# 4️⃣ Syntax verify
if zsh -n "$target"; then
  echo "✅ Syntax repaired"
else
  echo "⚠️ Syntax still invalid — inspect manually"
fi
