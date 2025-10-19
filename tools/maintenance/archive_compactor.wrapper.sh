#!/bin/zsh
set -euo pipefail
LOCK="/tmp/archive_compactor.lock"
if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
exec "$(dirname "$0")/archive_compactor.real.sh" "$@"
