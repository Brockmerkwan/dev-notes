#!/usr/bin/env bash
set -euo pipefail
REP_DIR="${REP_DIR:-$HOME/.local/share/brock/reports}"
J="$(ls -1t "$REP_DIR"/sys_scan_*.json 2>/dev/null | head -1 || true)"
[[ -z "$J" ]] && { echo "sys-scan: no reports"; exit 0; }
ts=$(jq -r '.timestamp' "$J")
brew=$(jq -r '.counts.brew' "$J")
cask=$(jq -r '.counts.cask' "$J")
pip=$(jq -r '.counts.pip' "$J")
npm=$(jq -r '.counts.npm' "$J")
gem=$(jq -r '.counts.gem' "$J")
stat=$(jq -r '.status' "$J")
echo "sys-scan[$stat] ts=$ts brew=$brew cask=$cask pip=$pip npm=$npm gem=$gem"
