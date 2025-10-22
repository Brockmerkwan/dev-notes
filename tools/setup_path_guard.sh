#!/usr/bin/env bash
set -euo pipefail
# ────────────────────────────────────────────────
# Phase 1 — Create include_path_guard.sh
# ────────────────────────────────────────────────
cd "$(dirname "${BASH_SOURCE[0]}")"/.. || exit 1
LOG_DIR="$HOME/.local/state/devnotes"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/path_guard_setup_$(date +%Y%m%d_%H%M%S).log"

cat > tools/include_path_guard.sh <<'GUARD'
#!/usr/bin/env bash
set -euo pipefail
# Detect current script location for Bash or Zsh
if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [ -n "${(%):-%x}" ] 2>/dev/null; then
  SCRIPT_PATH="${(%):-%x}"
else
  SCRIPT_PATH="$0"
fi
# Normalize to repo root
cd "$(dirname "$SCRIPT_PATH")/.." || exit 1
export DEVROOT="$(pwd)"
echo "✅ DEVROOT=$DEVROOT"
GUARD

chmod +x tools/include_path_guard.sh
echo "✅ Created tools/include_path_guard.sh" | tee "$LOG_FILE"

# ────────────────────────────────────────────────
# Phase 2 — Validation
# ────────────────────────────────────────────────
echo "🔍 Test 1: from inside repo" | tee -a "$LOG_FILE"
bash tools/include_path_guard.sh | tee -a "$LOG_FILE"

echo "🔍 Test 2: from /tmp external path" | tee -a "$LOG_FILE"
(cd /tmp && ~/Projects/devnotes/tools/include_path_guard.sh) | tee -a "$LOG_FILE"

echo "📦 Log → $LOG_FILE"

