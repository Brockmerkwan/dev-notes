#!/usr/bin/env bash
set -euo pipefail
REP="$HOME/.local/share/brock/reports/sys_scan_latest.json"
if [[ ! -f "$REP" ]]; then
  echo "suite: no sys_scan report yet"; exit 0
fi
jq -r '"suite[ok] " +
      "macOS=\(.macos) " +
      "brew=\(.counts.brew) cask=\(.counts.cask) pip=\(.counts.pip) npm=\(.counts.npm) gem=\(.counts.gem) " +
      "disk_warn=\(.disk_warning)"' "$REP"
