#!/usr/bin/env bash
set -euo pipefail

CONF_DIR="${HOME}/.config/brock_core"
STATE_DIR="${HOME}/.local/state/brock_core"
PLIST="${HOME}/Library/LaunchAgents/com.brock.dashboard.http.plist"
RULES="${CONF_DIR}/triage.rules"
IGNORE="${CONF_DIR}/triage.ignore"

mkdir -p "$CONF_DIR"

# Seed default rules if missing
if [ ! -f "$RULES" ]; then
  cat >"$RULES" <<'R'
Boot-out failed: 3: No such process|ignore|Expected during clean pave when agent wasn't loaded.
Address already in use|fix|Port conflict; stale process or duplicate agent.
OSError: \[Errno 48\]|fix|Python bind conflict (same as 'Address already in use').
throttled: last push|ignore|Notification throttle; working as designed.
HTTP/1\.0 401 Unauthorized|ignore|Auth guard for /api/* without token.
R
fi
: >"$IGNORE" 2>/dev/null || true

MODE="${1---scan}"
ARG2="${2-}"
TAIL="${TAIL_LINES:-400}"

die(){ echo "ERR: $*" >&2; exit 1; }

collect_logs() {
  # Echo existing log paths, one per line
  local from="$1"
  if [ -n "$from" ]; then
    if [ -d "$from" ]; then
      for f in "$from"/*.log "$from"/*.out "$from"/*.err; do [ -f "$f" ] && echo "$f"; done
    elif [ -f "$from" ]; then
      echo "$from"
    fi
  fi
  [ -f "$STATE_DIR/dashboard_http.out" ] && echo "$STATE_DIR/dashboard_http.out"
  [ -f "$STATE_DIR/dashboard_http.err" ] && echo "$STATE_DIR/dashboard_http.err"
  [ -f "$HOME/.local/state/aiwatcher/aiwatcher.log" ] && echo "$HOME/.local/state/aiwatcher/aiwatcher.log"

  if [ -f "$PLIST" ]; then
    # Extract StandardOutPath / StandardErrorPath (simple XML grep)
    sout="$(awk -F'[<>]' '/StandardOutPath/{getline;print $3}' "$PLIST" 2>/dev/null || true)"
    serr="$(awk -F'[<>]' '/StandardErrorPath/{getline;print $3}' "$PLIST" 2>/dev/null || true)"
    [ -n "${sout:-}" ] && [ -f "$sout" ] && echo "$sout"
    [ -n "${serr:-}" ] && [ -f "$serr" ] && echo "$serr"
  fi
}

scan() {
  FROM="$ARG2"
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  all="$tmpdir/all.log"; : >"$all"

  # Gather logs
  dedup="$tmpdir/list.txt"; : >"$dedup"
  collect_logs "$FROM" | sed '/^\s*$/d' | awk '!seen[$0]++' > "$dedup"
  if [ ! -s "$dedup" ]; then
    echo "ERR: no logs found."
    echo "hint:"
    echo "  launchctl kickstart -k gui/$(id -u)/com.brock.dashboard.http"
    echo "  curl -s -o /dev/null http://127.0.0.1:7780/ || true"
    exit 3
  fi

  while IFS= read -r f; do
    echo "## $(basename "$f")" >>"$all"
    tail -n "$TAIL" "$f" >>"$all" 2>/dev/null || true
    echo "" >>"$all"
  done <"$dedup"

  # Normalize rules/acks into temp files
  rules="$tmpdir/rules.txt"; acks="$tmpdir/acks.txt"
  grep -v '^\s*#' "$RULES" | sed '/^\s*$/d' > "$rules"
  [ -f "$IGNORE" ] && grep -v '^\s*#' "$IGNORE" | sed '/^\s*$/d' > "$acks" || : >"$acks"

  fix_hits=0
  action="$tmpdir/action.txt"; : >"$action"
  ignore="$tmpdir/ignore.txt"; : >"$ignore"
  details="$tmpdir/details.txt"; : >"$details"

  # For each rule, count matches and classify
  while IFS='|' read -r pat sev why; do
    [ -n "${pat:-}" ] || continue
    # Skip if acknowledged
    if grep -E -q -- "^${pat}\$" "$acks" 2>/dev/null; then
      continue
    fi
    count="$(grep -E -c -- "$pat" "$all" || true)"
    [ "$count" -eq 0 ] && continue

    case "$sev" in
      fix)    printf " - %s (%s hits)\n" "$pat" "$count" >>"$action"; fix_hits=$((fix_hits+count));;
      ignore) printf " - %s (%s hits)\n" "$pat" "$count" >>"$ignore";;
      *)      printf " - %s (%s hits)\n" "$pat" "$count" >>"$ignore";;
    esac

    # Emit details lines (first 8 matches to keep output short)
    grep -E -n -- "$pat" "$all" | head -n 8 | while IFS= read -r line; do
      printf "%-6s | %-40s | %s\n    ↳ %s\n" "${sev:-unk}" "$pat" "$why" "$line" >>"$details"
    done
  done <"$rules"

  echo "=== Error Triage (tail ${TAIL}) ==="
  echo ""
  echo "[ ACTION REQUIRED ]"
  if [ -s "$action" ]; then cat "$action"; else echo " - none"; fi
  echo ""
  echo "[ SAFE TO IGNORE ]"
  if [ -s "$ignore" ]; then cat "$ignore"; else echo " - none"; fi
  echo ""
  echo "[ DETAILS ]"
  if [ -s "$details" ]; then cat "$details"; else echo " - (no matches)"; fi

  [ "$fix_hits" -gt 0 ] && exit 2 || exit 0
}

ack() {
  pat="${ARG2:-}"; [ -n "$pat" ] || die "usage: --ack 'REGEX'"
  echo "$pat" >>"$IGNORE"
  sort -u "$IGNORE" -o "$IGNORE"
  echo "✅ ack: $pat"
}

clear_acks() { : >"$IGNORE"; echo "✅ acks cleared"; }

case "${MODE}" in
  --scan)        scan ;;
  --from)        MODE="--scan"; scan ;;
  --ack)         ack ;;
  --clear-acks)  clear_acks ;;
  *) die "usage: error_triage.sh [--scan] [--from PATH] [--ack REGEX] [--clear-acks]" ;;
esac
