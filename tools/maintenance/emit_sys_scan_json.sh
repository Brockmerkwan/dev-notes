#!/usr/bin/env bash
set -euo pipefail
MEM_DIR="${MEM_DIR:-$HOME/.local/share/brock}"
REP_DIR="${REP_DIR:-$MEM_DIR/reports}"
LOG_DIR="${LOG_DIR:-$MEM_DIR/logs}"
mkdir -p "$REP_DIR"

# TS from latest log filename if present; else now
latest_log="$(ls -1t "$LOG_DIR"/sys_scan_*.log 2>/dev/null | head -1 || true)"
if [[ -n "${latest_log:-}" ]]; then
  TS="$(basename "$latest_log" .log | sed 's/sys_scan_//')"
else
  TS="$(date +%Y%m%d_%H%M%S)"
fi

has() { command -v "$1" >/dev/null 2>&1; }
n_lines() { wc -l | awk '{print $1}'; }

# Recount live
OUTDATED_CNT=0; CASK_CNT=0; PIP_CNT=0; NPM_CNT=0; GEM_CNT=0; DISK_WARN=0
if has brew; then
  OUTDATED="$(brew outdated || true)"; OUTDATED_CNT="$(printf "%s\n" "$OUTDATED" | n_lines)"
  CASK_OUT="$(brew outdated --cask || true)"; CASK_CNT="$(printf "%s\n" "$CASK_OUT" | sed '/^$/d' | n_lines)"
fi
if has pip3; then
  PIP_OUT="$(pip3 list --user --outdated --format=columns 2>/dev/null || true)"
  PIP_CNT="$(printf "%s\n" "$PIP_OUT" | awk 'NR>2' | n_lines)"
fi
if has npm; then
  JSONTMP="$(npm -g outdated --json 2>/dev/null || echo '{}')"
  [[ -z "$JSONTMP" || "$JSONTMP" == "null" ]] && JSONTMP="{}"
  NPM_CNT="$(python3 - <<'PY' <<<"$JSONTMP" 2>/dev/null || echo 0
import json,sys
try:
  d=json.load(sys.stdin); print(0 if not isinstance(d,dict) else len(d))
except:
  print(0)
PY
)"
fi
if has gem; then
  GEM_OUT="$(gem outdated 2>/dev/null || true)"; GEM_CNT="$(printf "%s\n" "$GEM_OUT" | sed '/^$/d' | n_lines)"
fi

# Disk warn
while read -r line; do
  fs="$(echo "$line" | awk '{print $1}')"
  pct="$(echo "$line" | awk '{print $(NF-1)}' | tr -d '%')"
  [[ "$pct" =~ ^[0-9]+$ ]] || continue
  case "$fs" in devfs|map|procfs|overlay) continue;; esac
  (( pct >= 95 )) && DISK_WARN=1 && break
done < <(df -h | tail -n +2)

JSON="$REP_DIR/sys_scan_${TS}.json"
STATUS="ok"; [[ "$DISK_WARN" -eq 1 ]] && STATUS="warn"

cat > "$JSON" <<J
{
  "timestamp": "$TS",
  "hostname": "$(scutil --get LocalHostName 2>/dev/null || hostname)",
  "macos": "$(sw_vers -productVersion 2>/dev/null || echo "N/A")",
  "counts": { "brew": $OUTDATED_CNT, "cask": $CASK_CNT, "pip": $PIP_CNT, "npm": $NPM_CNT, "gem": $GEM_CNT },
  "disk_warning": $DISK_WARN,
  "status": "$STATUS",
  "log": "${latest_log:-""}",
  "memory": "$MEM_DIR/memory.md"
}
J

ln -sf "$JSON" "$REP_DIR/sys_scan_latest.json"
echo "📊 JSON → $JSON"
