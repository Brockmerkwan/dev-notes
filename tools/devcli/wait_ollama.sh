#!/bin/zsh
set -euo pipefail
URL="${1:-http://localhost:11434/api/version}"
for i in {1..30}; do
  if curl -sS "$URL" >/dev/null 2>&1; then exit 0; fi
  sleep 2
done
echo "Ollama not ready after 60s: $URL" >&2
exit 1
