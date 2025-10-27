#!/usr/bin/env bash
set -euo pipefail
MODEL="brock-core"
API="http://localhost:11434/api/generate"

usage() {
  echo "Usage: $0 [--model name] [--system prompt] [--stream]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --system) SYSTEM="$2"; shift 2 ;;
    --stream) STREAM=true; shift ;;
    *) usage ;;
  esac
done

echo "💬 Chatting with $MODEL (Ctrl+C to exit)"
while true; do
  read -erp "> " PROMPT || break
  [[ -z "$PROMPT" ]] && continue
  curl -s -N "$API" \
    -d "$(jq -n --arg m "$MODEL" --arg p "$PROMPT" --arg sys "${SYSTEM:-You are Brock Core OS, respond concisely and conversationally.}" '{model:$m, prompt:$p, system:$sys, stream:true}')" \
    | jq -r -j 'select(.response != null) | .response'
  echo -e "\n"
done