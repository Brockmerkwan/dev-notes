#!/usr/bin/env zsh
set -euo pipefail
f="$HOME/Projects/devnotes/core.sh"
echo "🔍 Scanning for unquoted log: lines..."
grep -nE 'log:' "$f" | grep -v '"'
