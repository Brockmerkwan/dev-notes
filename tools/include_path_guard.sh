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
