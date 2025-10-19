#!/bin/zsh
set -euo pipefail
ARC="$HOME/Downloads/_Archive"; [[ -d "$ARC" ]] || exit 0
KEEP="${KEEP_DAYS:-90}"; CUR=$(date +%Y-%m)
find "$ARC" -mindepth 2 -maxdepth 2 -type d ! -name "$CUR" | while read -r D; do
  B="$(basename "$D")"; C="$(basename "$(dirname "$D")")"
  AGE=$(( ( $(date +%s) - $(date -r "$D" +%s) ) / 86400 )); [[ $AGE -lt $KEEP ]] && continue
  OUT="$ARC/${C}_${B}.tar.gz"; [[ -f "$OUT" ]] || tar -czf "$OUT" -C "$(dirname "$D")" "$B"
  [[ "${PURGE_OLD:-0}" = 1 ]] && rm -rf "$D"
done
