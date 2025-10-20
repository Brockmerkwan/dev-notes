#!/usr/bin/env bash
set -euo pipefail
STATE="$HOME/.local/state/aiwatcher"
ARCH="$STATE/archive"
mkdir -p "$ARCH"
find "$STATE" -name "*.log" -type f -mtime +7 -exec gzip -f {} \; -exec mv {}.gz "$ARCH" \;
find "$ARCH" -type f -mtime +30 -delete
echo "$(date '+%F %T') rotation done"
