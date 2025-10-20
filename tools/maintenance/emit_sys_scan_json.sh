#!/usr/bin/env bash
set -euo pipefail

MEM_DIR="${MEM_DIR:-$HOME/.local/share/brock}"
REP_DIR="${REP_DIR:-$MEM_DIR/reports}"
LOG_DIR="${LOG_DIR:-$MEM_DIR/logs}"
mkdir -p "$REP_DIR"

# Timestamp from latest scan log if present; else now
latest_log="$(ls -1t "$LOG_DIR"/sys_scan_*.log 2>/dev/null | head -1 || true)"
if [[ -n "${latest_log:-}" ]]; then
  TS="$(basename "$latest_log" .log | sed 's/sys_scan_//')"
else
  TS="$(date +%Y%m%d_%H%M%S)"
fi

has() { command -v "$1" >/dev/null 2>&1; }
num() { [[ "$1" =~ ^[0-9]+$ ]] && echo "$1" || echo 0; }

# Live recounts (authoritative) — defaults
OUTDATED_CNT=0; CASK_CNT=0; PIP_CNT=0; NPM_CNT=0; GEM_CNT=0; DISK_WARN=0

# Homebrew via JSON v2
if has brew && has jq; then
  OUTDATED_CNT="$(brew outdated --json=v2 2>/dev/null | jq -r '.outdated_formulae|length // 0' || echo 0)"
  CASK_CNT="$(brew outdated --cask --json=v2 2>/dev/null | jq -r '.outdated_casks|length // 0' || echo 0)"
elif has brew; then
  # Fallback without jq (line-count, may be less accurate)
  OUTDATED_CNT="$(brew outdated 2>/dev/null | wc -l | awk '{print $1}')"
  CASK_CNT="$(brew outdated --cask 2>/dev/null | sed '/^$/d' | wc -l | awk '{print $1}')"
fi

# pip (user)
if has pip3; then
  PIP_OUT="$(pip3 list --user --outdated --format=columns 2>/dev/null || true)"
  PIP_CNT="$(printf "%s\n" "$PIP_OUT" | awk 'NR>2' | wc -l | awk '{print $1}')"
fi

# npm -g
if has npm; then
  JSONTMP="$(npm -g outdated --json 2>/dev/null || echo '{}')"
  [[ -z "$JSONTMP" || "$JSONTMP" == "null" ]] && JSONTMP="{}"
  NPM_CNT="$(python3 - <<'PY' <<<"$JSONTMP" 2>/dev/null || echo 0
import json,sys
try:
  d=json.load(sys.stdin)
  print(len(d) if isinstance(d,dict) else 0)
except:
  print(0)
PY
)"
fi

# gems
if has gem; then
  GEM_OUT="$(gem outdated 2>/dev/null || true)"
  GEM_CNT="$(printf "%s\n" "$GEM_OUT" | sed '/^$/d' | wc -l | awk '{print $1}')"
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
STATUS="ok"; [[ "$(num "$DISK_WARN")" -ge 1 ]] && STATUS="warn"

# Assemble JSON safely with jq -n
jq -n \
  --arg ts "$TS" \
  --arg hostname "$(scutil --get LocalHostName 2>/dev/null || hostname)" \
  --arg macos "$(sw_vers -productVersion 2>/dev/null || echo N/A)" \
  --arg log "${latest_log:-}" \
  --arg memory "$MEM_DIR/memory.md" \
  --arg status "$STATUS" \
  --argjson brew "$(num "$OUTDATED_CNT")" \
  --argjson cask "$(num "$CASK_CNT")" \
  --argjson pip  "$(num "$PIP_CNT")" \
  --argjson npm  "$(num "$NPM_CNT")" \
  --argjson gem  "$(num "$GEM_CNT")" \
  --argjson disk "$(num "$DISK_WARN")" \
  '{
     timestamp: $ts,
     hostname: $hostname,
     macos: $macos,
     counts: { brew: $brew, cask: $cask, pip: $pip, npm: $npm, gem: $gem },
     disk_warning: $disk,
     status: $status,
     log: $log,
     memory: $memory
   }' > "$JSON"

ln -sf "$JSON" "$REP_DIR/sys_scan_latest.json"
echo "📊 JSON → $JSON"
