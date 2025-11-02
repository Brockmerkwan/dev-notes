#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/Projects/devnotes"
TOOLS="$ROOT/tools"
STATE="$HOME/.local/state/brock_core"
PORT="${CORE_DASH_PORT:-7780}"

mkdir -p "$TOOLS" "$STATE" "$ROOT/docs"

log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$STATE/install_core_suite.log"; }

# ---- core.sh (enhanced) -----------------------------------------------------
cat > "$TOOLS/core.sh" <<'SH'
#!/usr/bin/env bash
# Brock Core OS — main menu (enhanced)
set -euo pipefail
SCRIPT="$(basename "${BASH_SOURCE[0]:-$0}")"
STATE_DIR="${HOME}/.local/state/brock_core"; mkdir -p "$STATE_DIR"
LOG="${STATE_DIR}/core.log"; log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
require(){ command -v "$1" >/dev/null 2>&1 || { log "ERR: missing dep: $1"; exit 1; }; }

PROJECT_DIR="${HOME}/Projects/devnotes"
PROMPT_FILE="${PROJECT_DIR}/system_prompts/brock_core_os_v3.md"

health(){ log "[health]"; echo "OS: $(sw_vers -productVersion 2>/dev/null || uname -a)"; df -h / | awk 'NR==1||NR==2'; vm_stat | awk '/free/ {print "Free RAM pages: "$3}'; }
sync(){ require git; cd "$PROJECT_DIR"; git fetch --all --prune; if ! git diff --quiet || ! git diff --cached --quiet; then git add -A; git commit -m "chore(sync): DevNotes auto-sync via core.sh"; git push; log "sync: pushed"; else log "sync: clean"; fi; }
prompt(){ [[ -s "$PROMPT_FILE" ]] && { echo "$PROMPT_FILE"; open -R "$PROMPT_FILE" 2>/dev/null || true; } || log "WARN: prompt missing"; }

aiwatch(){ "$PROJECT_DIR/tools/aiwatcher.sh" "${@:---once}"; }
dash(){ "$PROJECT_DIR/tools/core_dash.sh"; }

web_start(){ "$PROJECT_DIR/tools/core_web.sh" --start; }
web_stop(){ "$PROJECT_DIR/tools/core_web.sh" --stop; }
web_status(){ "$PROJECT_DIR/tools/core_web.sh" --status; open "http://localhost:${CORE_DASH_PORT:-7780}" 2>/dev/null || true; }

usage(){ cat <<USG
$SCRIPT — menu
  $SCRIPT                # interactive
  $SCRIPT --health
  $SCRIPT --sync
  $SCRIPT --prompt
  $SCRIPT --aiwatch [flags]
  $SCRIPT --dash
  $SCRIPT --web-start|--web-stop|--web-status
USG
}

menu(){
  PS3="Select: "
  select opt in \
    "Health Check" "Sync DevNotes" "Open Prompt" \
    "Run AI Watcher once" "Dashboard (CLI)" \
    "Web Dashboard START" "Web Dashboard STATUS" "Web Dashboard STOP" "Exit"
  do
    case "$REPLY" in
      1) health ;;
      2) sync ;;
      3) prompt ;;
      4) aiwatch --once ;;
      5) dash ;;
      6) web_start ;;
      7) web_status ;;
      8) web_stop ;;
      9) exit 0 ;;
      *) echo "Invalid";;
    esac
  done
}

case "${1-}" in
  --health) health ;;
  --sync) sync ;;
  --prompt) prompt ;;
  --aiwatch) shift || true; aiwatch "$@" ;;
  --dash) dash ;;
  --web-start) web_start ;;
  --web-stop) web_stop ;;
  --web-status) web_status ;;
  "" ) menu ;;
  * ) usage ;;
esac
SH
chmod +x "$TOOLS/core.sh"

# ---- CLI dashboard (already installed previously; ensure exists) ------------
if [[ ! -x "$TOOLS/core_dash.sh" ]]; then
cat > "$TOOLS/core_dash.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf "\n🧠 Brock Core OS — Dashboard\n"
printf "───────────────────────────────\n"

printf "\n[ Services ]\n"
launchctl list | awk '$3 ~ /^com\.brock\./ {print $1"\t"$2"\t"$3}'

printf "\n[ Watcher Status ]\n"
LOG="$HOME/.local/state/aiwatcher/aiwatcher.log"
if [[ -s "$LOG" ]]; then tail -n 5 "$LOG"; else echo "No watcher log yet."; fi

printf "\n[ Storage / Memory ]\n"
df -h / | awk 'NR==1||NR==2'
vm_stat | awk '/free/ {print "Free RAM pages: "$3}'

printf "\n[ Git Sync Status ]\n"
cd ~/Projects/devnotes
git status -sb || echo "Git status unavailable"

printf "\n✅ Dashboard complete\n"
SH
chmod +x "$TOOLS/core_dash.sh"
fi

# ---- Web server (Python stdlib) --------------------------------------------
cat > "$TOOLS/core_dash_web.py" <<'PY'
#!/usr/bin/env python3
import json, os, subprocess, time
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("CORE_DASH_PORT", "7780"))
STATE = os.path.expanduser("~/.local/state")
DEV = os.path.expanduser("~/Projects/devnotes")

def sh(cmd):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=6)
        return out.strip()
    except subprocess.CalledProcessError as e:
        return e.output.strip()
    except Exception as e:
        return f"ERR: {e}"

def status():
    return {
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "services": sh("launchctl list | awk '$3 ~ /^com\\.brock\\./ {print $1\"\\t\"$2\"\\t\"$3}'"),
        "watcher": sh("tail -n 20 ~/.local/state/aiwatcher/aiwatcher.log 2>/dev/null || echo 'no log'"),
        "disk": sh("df -h / | awk 'NR==1||NR==2'"),
        "mem": sh("vm_stat | awk '/free/ {print \"Free RAM pages: \"$3}'"),
        "git": sh(f"cd {DEV} && git status -sb || echo 'git unavailable'"),
    }

HTML = """<!doctype html>
<html><head><meta charset='utf-8'><title>Brock Core OS</title>
<style>
body{font-family:system-ui, -apple-system, Segoe UI, Roboto, sans-serif;margin:0;background:#0b0f14;color:#e6e8eb}
h1{margin:0;padding:16px;background:#111827;border-bottom:1px solid #1f2937}
section{padding:16px;border-bottom:1px solid #1f2937}
pre{background:#0f172a;padding:12px;border-radius:6px;overflow:auto}
small{color:#9ca3af}
a{color:#93c5fd}
.btn{display:inline-block;padding:8px 12px;border:1px solid #334155;border-radius:6px;text-decoration:none;color:#e6e8eb;margin-right:8px}
</style>
<script>
async function reloadNow(){
  const r = await fetch('/api/status'); const j = await r.json();
  document.getElementById('ts').textContent = j.time;
  document.getElementById('svc').textContent = j.services;
  document.getElementById('watch').textContent = j.watcher;
  document.getElementById('disk').textContent = j.disk;
  document.getElementById('mem').textContent = j.mem;
  document.getElementById('git').textContent = j.git;
}
setInterval(reloadNow, 15000); // 15s
window.onload = reloadNow;
</script>
</head><body>
<h1>🧠 Brock Core OS — Web Dashboard <small id="ts"></small></h1>
<section>
  <a class="btn" href="/api/status" target="_blank">/api/status (JSON)</a>
  <a class="btn" href="/" onclick="reloadNow();return false;">Refresh</a>
</section>
<section><h2>Services</h2><pre id="svc">loading…</pre></section>
<section><h2>Watcher</h2><pre id="watch">loading…</pre></section>
<section><h2>Storage / Memory</h2><pre id="disk">loading…</pre><pre id="mem">loading…</pre></section>
<section><h2>Git</h2><pre id="git">loading…</pre></section>
</body></html>
"""

class H(BaseHTTPRequestHandler):
    def _send(self, code, ctype, body):
        self.send_response(code); self.send_header("Content-Type", ctype); self.end_headers()
        if isinstance(body, str): body = body.encode()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/status"):
            self._send(200, "application/json", json.dumps(status()))
        elif self.path == "/" or self.path.startswith("/index.html"):
            self._send(200, "text/html; charset=utf-8", HTML)
        else:
            self._send(404, "text/plain", "not found")

def main():
    srv = HTTPServer(("127.0.0.1", PORT), H)
    print(f"[core_dash_web] listening on http://127.0.0.1:{PORT}")
    srv.serve_forever()

if __name__ == "__main__":
    main()
PY
chmod +x "$TOOLS/core_dash_web.py"

# ---- web wrapper ------------------------------------------------------------
cat > "$TOOLS/core_web.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PORT="${CORE_DASH_PORT:-7780}"
STATE="$HOME/.local/state/brock_core"
OUT="$STATE/dashboard_http.out"
ERR="$STATE/dashboard_http.err"
PY="$HOME/Projects/devnotes/tools/core_dash_web.py"

start(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; nohup "$PY" >>"$OUT" 2>>"$ERR" & sleep 0.5; echo "started on :$PORT"; }
stop(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; echo "stopped"; }
status(){ pgrep -fl core_dash_web.py >/dev/null && { echo "RUNNING on :$PORT"; } || { echo "STOPPED"; }; }
serve(){ exec "$PY"; }

case "${1-}" in
  --start) start ;;
  --stop) stop ;;
  --status) status ;;
  --serve) serve ;;
  *) echo "usage: $0 --start|--stop|--status|--serve";;
esac
SH
chmod +x "$TOOLS/core_web.sh"

# ---- LaunchAgent ------------------------------------------------------------
PL="$HOME/Library/LaunchAgents/com.brock.dashboard.http.plist"
cat > "$PL" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0"><dict>
  <key>Label</key><string>com.brock.dashboard.http</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>CORE_DASH_PORT=${PORT} ~/Projects/devnotes/tools/core_web.sh --serve</string>
  </array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${HOME}/.local/state/brock_core/dashboard_http.out</string>
  <key>StandardErrorPath</key><string>${HOME}/.local/state/brock_core/dashboard_http.err</string>
</dict></plist>
PLIST
launchctl unload "$PL" 2>/dev/null || true
launchctl load "$PL"

# ---- docs + gitignore -------------------------------------------------------
cat > "$ROOT/docs/core_suite.md" <<'MD'
# Brock Core OS — Core Suite
- **core.sh**: main menu (health, sync, prompt, watcher, dashboards)
- **core_dash.sh**: CLI dashboard
- **core_dash_web.py** + **core_web.sh**: Web dashboard at `http://localhost:7780`
LaunchAgents: `com.brock.dashboard.http` (web), `com.brock.aiwatcher` (watcher), `com.brock.logrotate` (logs)
MD

# ensure ignores
grep -qxF ".DS_Store" "$ROOT/.gitignore" 2>/dev/null || echo ".DS_Store" >> "$ROOT/.gitignore"
grep -qxF "*.tmp" "$ROOT/.gitignore" 2>/dev/null || echo "*.tmp" >> "$ROOT/.gitignore"
grep -qxF "backups/" "$ROOT/.gitignore" 2>/dev/null || echo "backups/" >> "$ROOT/.gitignore"

# ---- commit & push ----------------------------------------------------------
cd "$ROOT"
git add tools/core.sh tools/core_web.sh tools/core_dash_web.py docs/core_suite.md .gitignore
git commit -m "feat(core): unify CLI + web dashboard (LaunchAgent), docs, ignores"
git push

log "Core suite installed."
echo "Open: http://localhost:${PORT}"
