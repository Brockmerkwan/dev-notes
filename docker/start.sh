#!/usr/bin/env bash
set -euo pipefail
RSS_CONF="${RSS_CONF:-/app/rss.yaml}"
: "${RSS_PUSH_BATCH:=1}"
: "${RSS_MAX_PUSH:=8}"
: "${OLLAMA_MODEL:=llama3.1:8b}"
ts(){ date +%F_%T; }
echo "[$(ts)] boot | RSS_CONF=$RSS_CONF RSS_NOAI=${RSS_NOAI:-0} OLLAMA_HOST=${OLLAMA_HOST:-}"

# Start local Ollama only if AI is enabled and no OLLAMA_HOST provided
if [[ "${RSS_NOAI:-0}" != "1" ]]; then
  if [[ -z "${OLLAMA_HOST:-}" ]]; then
    echo "[$(ts)] starting local ollama..."
    nohup /usr/local/bin/ollama serve >/tmp/ollama.log 2>&1 &
    for _ in {1..40}; do
      curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && { export OLLAMA_HOST="http://127.0.0.1:11434"; break; }
      sleep 1
    done
    echo "[$(ts)] OLLAMA_HOST=${OLLAMA_HOST:-none}"
    [[ -n "${OLLAMA_HOST:-}" ]] && /usr/local/bin/ollama pull "$OLLAMA_MODEL" || true
  fi
else
  echo "[$(ts)] AI scoring disabled (RSS_NOAI=1)"
fi

echo "[$(ts)] 🧠 run watcher"; python3 /app/rss_ai_watcher.py || true
echo "[$(ts)] ❤️ heartbeat"; bash /app/heartbeat.sh || true
# hourly loop
while true; do
  sleep 3600
  echo "[$(ts)] 🧠 run watcher"; python3 /app/rss_ai_watcher.py || true
  echo "[$(ts)] ❤️ heartbeat"; bash /app/heartbeat.sh || true
done
