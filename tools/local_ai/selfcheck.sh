#!/usr/bin/env bash
set -euo pipefail
ok=()
warn=()

need() { command -v "$1" >/dev/null 2>&1 || warn+=("missing:$1"); }
need jq
need brew
need python3
need npm
need gem

[[ -f "$HOME/.local/share/brock/reports/sys_scan_latest.json" ]] || warn+=("no_report")
[[ -s "$HOME/.local/share/brock/memory.md" ]] || warn+=("no_memory")

if launchctl print "gui/$(id -u)/com.brock.sysscan.daily" >/dev/null 2>&1; then
  ok+=("launchd:sysscan")
else
  warn+=("launchd:sysscan:not_loaded")
fi

printf 'selfcheck: ok=%s warn=%s\n' "$(IFS=,; echo "${ok[*]:-none}")" "$(IFS=,; echo "${warn[*]:-none}")"
exit 0
