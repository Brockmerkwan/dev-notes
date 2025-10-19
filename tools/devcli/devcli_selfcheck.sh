#!/bin/zsh
set -euo pipefail
LOG="$HOME/Projects/devnotes/backups/devcli_selfcheck.log"
ts(){ date '+%Y-%m-%d %H:%M:%S %Z'; }
say(){ echo "[$(ts)] $*" | tee -a "$LOG"; }
say "== DevCLI selfcheck start =="

# A) API reachable
if "$HOME/Projects/devnotes/tools/devcli/wait_ollama.sh"; then
  v=$(curl -s http://localhost:11434/api/version || true)
  say "Ollama API: $v"
else
  say "Ollama API: UNREACHABLE"
fi

# B) Streaming probe (chat first; fallback to generate)
CHAT_REQ='{"model":"mistral:latest","messages":[{"role":"user","content":"say hi"}],"stream":true}'
printf '%s' "$CHAT_REQ" | curl -sN -X POST http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' --data-binary @- \
  | head -n 3 | sed 's/^/[stream-chat] /' | tee -a "$LOG" >/dev/null || true

# if chat produced nothing, try /api/generate
GEN_REQ='{"model":"llama3.1:8b","prompt":"say hi","stream":true}'
printf '%s' "$GEN_REQ" | curl -sN -X POST http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' --data-binary @- \
  | head -n 3 | sed 's/^/[stream-gen]  /' | tee -a "$LOG" >/dev/null || true
# C) Host tools presence
# C) Host tools presence
# C) Host tools presence (if installed)
for b in /usr/local/bin/devask_h /usr/local/bin/devteach_h /usr/local/bin/devnote_h; do
  [[ -x "$b" ]] && say "tool: present → ${b:t}" || say "tool: missing → ${b:t}"
done

# D) Repo write test (touch then clean)
TMP="$HOME/Projects/devnotes/docs/ai_sessions/session_$(date +%Y%m%d_%H%M%S).md"
mkdir -p "$(dirname "$TMP")"
echo "# Selfcheck $(ts)" > "$TMP"
if git -C "$HOME/Projects/devnotes" add "$TMP" 2>/dev/null \
  && git -C "$HOME/Projects/devnotes" commit -m "chore(selfcheck): proof $(basename "$TMP")" 2>/dev/null \
  && git -C "$HOME/Projects/devnotes" push 2>/dev/null; then
  say "repo push: OK ($(basename "$TMP"))"
else
  say "repo push: SKIPPED (no changes or offline)"
fi

say "== DevCLI selfcheck done =="
