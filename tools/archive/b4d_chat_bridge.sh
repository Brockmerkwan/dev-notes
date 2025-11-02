#!/usr/bin/env bash
set -euo pipefail

# b4d_chat_bridge.sh — Ollama chat bridge for b4d
# Usage: ./b4d_chat_bridge.sh [--ping|--serve]
MODEL="brock-core"
HOST="127.0.0.1"
PORT="11434"

if [[ "${1:-}" == "--ping" ]]; then
  curl -s "http://${HOST}:${PORT}/api/tags" | grep -q "$MODEL" \
    && echo "[b4d] ✅ Ollama model '$MODEL' available on $HOST:$PORT" \
    || echo "[b4d] ❌ Model not found or Ollama not running."
  exit 0
fi

if [[ "${1:-}" == "--serve" ]]; then
  echo "[b4d] 🧠 Chat bridge online — listening for stdin"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "[b4d] ⇢ $line"
    curl -s -X POST "http://${HOST}:${PORT}/api/generate" \
      -d "{\"model\":\"$MODEL\",\"prompt\":\"$line\"}" \
      | jq -r '.response' | sed '/^$/d'
  done
  exit 0
fi

echo "Usage: $0 [--ping|--serve]"
