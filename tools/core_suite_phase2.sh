#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/Projects/devnotes"
TOOLS="$ROOT/tools"
STATE="$HOME/.local/state/brock_core"
CONF="$HOME/.config/brock_core"
PORT="${CORE_DASH_PORT:-7780}"

mkdir -p "$TOOLS" "$STATE" "$CONF"

# --- 0) Auth token -----------------------------------------------------------
if [[ ! -s "$CONF/core.env" ]]; then
  TOKEN="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
  cat > "$CONF/core.env" <<E
CORE_TOKEN="$TOKEN"
CORE_DASH_PORT="$PORT"
E
  echo "Generated CORE_TOKEN in $CONF/core.env"
fi
# shellcheck disable=SC1091
. "$CONF/core.env"
: "${CORE_TOKEN:?missing}"

# --- 1) Web server (overwrite) ----------------------------------------------
cat > "$TOOLS/core_dash_web.py" <<'PY'
#!/usr/bin/env python3
import json, os, subprocess, time, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("CORE_DASH_PORT", "7780"))
CORE_TOKEN = os.environ.get("CORE_TOKEN", "")  # required for /api/*
STATE = os.path.expanduser("~/.local/state")
DEV = os.path.expanduser("~/Projects/devnotes")

def sh(cmd):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=10)
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

def require_auth(headers):
    if not CORE_TOKEN:
        return True  # if unset, allow (dev-only)
    auth = headers.get("Authorization", "")
    return auth == f"Bearer {CORE_TOKEN}"

def json_body(req):
    length = int(req.headers.get("Content-Length", "0") or "0")
    data = req.rfile.read(length) if length else b""
    if not data:
        return {}
    try:
        return json.loads(data.decode("utf-8"))
    except Exception:
        return {}

def read_aiwatch_cfg():
    path = os.path.expanduser("~/.config/aiwatcher/config.env")
    out = {"exists": os.path.exists(path)}
    if not out["exists"]:
        return out
    with open(path, "r") as f:
        for line in f:
            line=line.strip()
            if not line or line.startswith("#"): continue
            k,v = (line.split("=",1)+[""])[:2]
            v = v.strip().strip("'").strip('"')
            out[k]=v
    # Normalize booleans
    for k in ["NTFY_ENABLED","NTFY_ON_EMPTY"]:
        if k in out: out[k] = str(out[k]).lower() in ("1","true","yes","on")
    if "NTFY_INTERVAL_MIN" in out:
        try: out["NTFY_INTERVAL_MIN"] = int(out["NTFY_INTERVAL_MIN"])
        except: pass
    return out

def write_aiwatch_cfg(payload):
    path = os.path.expanduser("~/.config/aiwatcher/config.env")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cur = read_aiwatch_cfg()
    # apply allowed keys only
    for k in ["NTFY_ENABLED","NTFY_ON_EMPTY","NTFY_INTERVAL_MIN","NTFY_URL","NTFY_TOPIC"]:
        if k in payload: cur[k] = payload[k]
    # normalize
    cur["NTFY_ENABLED"] = "true" if str(cur.get("NTFY_ENABLED","")).lower() in ("1","true","yes","on") else "false"
    cur["NTFY_ON_EMPTY"] = "true" if str(cur.get("NTFY_ON_EMPTY","")).lower() in ("1","true","yes","on") else "false"
    if "NTFY_INTERVAL_MIN" in cur:
        try: cur["NTFY_INTERVAL_MIN"] = str(int(cur["NTFY_INTERVAL_MIN"]))
        except: cur["NTFY_INTERVAL_MIN"]="30"
    # write back
    lines = []
    for k in ["NTFY_URL","NTFY_TOPIC","NTFY_ENABLED","NTFY_ON_EMPTY","NTFY_INTERVAL_MIN"]:
        if k in cur:
            v=str(cur[k])
            if k in ["NTFY_URL","NTFY_TOPIC"]:
                lines.append(f'{k}="{v}"')
            else:
                lines.append(f'{k}={v}')
    with open(path,"w") as f:
        f.write("# aiwatcher config (managed by web api)\n")
        f.write("\n".join(lines)+"\n")
    return True

def run_action(name):
    # Map action → command
    M = {
        "aiwatch_once": f"{DEV}/tools/aiwatcher.sh --once",
        "aiwatch_mute": f"{DEV}/tools/aiwatcher.sh --mute",
        "sync": f"cd {DEV} && git fetch --all --prune && (git diff --quiet && git diff --cached --quiet && echo 'clean' || (git add -A && git commit -m \"chore(sync): via web api\" && git push && echo 'pushed'))",
        "dash_cli": f"{DEV}/tools/core_dash.sh",
        "restart_web": "launchctl unload ~/Library/LaunchAgents/com.brock.dashboard.http.plist && launchctl load ~/Library/LaunchAgents/com.brock.dashboard.http.plist && echo 'restarted'",
    }
    cmd = M.get(name)
    if not cmd:
        return {"ok": False, "error": "unknown action"}
    out = sh(cmd)
    return {"ok": True, "action": name, "output": out}

HTML = """<!doctype html>
<html><head><meta charset='utf-8'><title>Brock Core OS</title>
<style>
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#0b0f14;color:#e6e8eb}
h1{margin:0;padding:16px;background:#111827;border-bottom:1px solid #1f2937}
section{padding:16px;border-bottom:1px solid #1f2937}
pre{background:#0f172a;padding:12px;border-radius:6px;overflow:auto}
small{color:#9ca3af}
a{color:#93c5fd}
.btn{display:inline-block;padding:8px 12px;border:1px solid #334155;border-radius:6px;text-decoration:none;color:#e6e8eb;margin-right:8px}
input,select{background:#0f172a;border:1px solid #334155;color:#e6e8eb;border-radius:6px;padding:6px}
label{margin-right:8px}
.row{margin:6px 0}
</style>
<script>
let token = localStorage.getItem('core_token')||'';
function setToken(){
  token = document.getElementById('t').value.trim();
  localStorage.setItem('core_token', token);
}
async function call(path, method='GET', body=null){
  const opt = {method, headers:{'Authorization':'Bearer '+token}};
  if(body){ opt.headers['Content-Type']='application/json'; opt.body=JSON.stringify(body); }
  const r = await fetch(path,opt); if(!r.ok){alert('HTTP '+r.status); return null;}
  return await r.json();
}
async function reloadNow(){
  const j = await call('/api/status'); if(!j) return;
  document.getElementById('ts').textContent = j.time;
  document.getElementById('svc').textContent = j.services;
  document.getElementById('watch').textContent = j.watcher;
  document.getElementById('disk').textContent = j.disk;
  document.getElementById('mem').textContent = j.mem;
  document.getElementById('git').textContent = j.git;
}
async function runAction(a){
  const j = await call('/api/run?'+new URLSearchParams({cmd:a}));
  if(j) alert((j.ok?'OK: ':'ERR: ')+a+'\\n\\n'+(j.output||j.error||''));
  reloadNow();
}
async function loadCfg(){
  const j = await call('/api/config/aiwatcher'); if(!j) return;
  document.getElementById('en').checked = !!j.NTFY_ENABLED;
  document.getElementById('em').checked = !!j.NTFY_ON_EMPTY;
  document.getElementById('iv').value = j.NTFY_INTERVAL_MIN||30;
  document.getElementById('topic').value = j.NTFY_TOPIC||'aiwatcher';
  document.getElementById('url').value = j.NTFY_URL||'https://ntfy.sh';
}
async function saveCfg(){
  const payload = {
    NTFY_ENABLED: document.getElementById('en').checked,
    NTFY_ON_EMPTY: document.getElementById('em').checked,
    NTFY_INTERVAL_MIN: parseInt(document.getElementById('iv').value||'30',10),
    NTFY_TOPIC: document.getElementById('topic').value,
    NTFY_URL: document.getElementById('url').value
  };
  const j = await call('/api/config/aiwatcher','POST',payload);
  if(j && j.ok) alert('Saved'); else alert('Save failed');
}
setInterval(reloadNow, 15000);
window.onload = ()=>{ document.getElementById('t').value = token; reloadNow(); loadCfg(); };
</script>
</head><body>
<h1>🧠 Brock Core OS — Web Dashboard <small id="ts"></small></h1>
<section>
  <input id="t" placeholder="Auth token" size="28"/><button class="btn" onclick="setToken()">Set Token</button>
  <a class="btn" href="/api/status" target="_blank">/api/status (JSON)</a>
  <button class="btn" onclick="reloadNow()">Refresh</button>
  <button class="btn" onclick="runAction('aiwatch_once')">Run Watcher Once</button>
  <button class="btn" onclick="runAction('sync')">Git Sync</button>
  <button class="btn" onclick="runAction('restart_web')">Restart Web</button>
</section>
<section><h2>Services</h2><pre id="svc">loading…</pre></section>
<section><h2>Watcher</h2><pre id="watch">loading…</pre></section>
<section><h2>Storage / Memory</h2><pre id="disk">loading…</pre><pre id="mem">loading…</pre></section>
<section><h2>Git</h2><pre id="git">loading…</pre></section>
<section>
  <h2>AI Watcher Config</h2>
  <div class="row"><label><input type="checkbox" id="en"/> Notifications Enabled</label>
                   <label><input type="checkbox" id="em"/> Notify on Empty</label></div>
  <div class="row"><label>Throttle (min) <input id="iv" type="number" min="0" value="30"/></label></div>
  <div class="row"><label>Topic <input id="topic" size="20"/></label>
                   <label>URL <input id="url" size="28"/></label></div>
  <button class="btn" onclick="saveCfg()">Save Config</button>
</section>
</body></html>
PY
chmod +x "$TOOLS/core_dash_web.py"

# --- 2) Wrapper (unchanged API, ensure present) ------------------------------
cat > "$TOOLS/core_web.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PORT="${CORE_DASH_PORT:-7780}"
STATE="$HOME/.local/state/brock_core"
OUT="$STATE/dashboard_http.out"
ERR="$STATE/dashboard_http.err"
PY="$HOME/Projects/devnotes/tools/core_dash_web.py"

start(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; nohup CORE_DASH_PORT="${PORT}" CORE_TOKEN="${CORE_TOKEN:-}" "$PY" >>"$OUT" 2>>"$ERR" & sleep 0.5; echo "started on :$PORT"; }
stop(){ pkill -f core_dash_web.py >/dev/null 2>&1 || true; echo "stopped"; }
status(){ pgrep -fl core_dash_web.py >/dev/null && { echo "RUNNING on :$PORT"; } || { echo "STOPPED"; }; }
serve(){ exec env CORE_DASH_PORT="${PORT}" CORE_TOKEN="${CORE_TOKEN:-}" "$PY"; }

case "${1-}" in
  --start) start ;;
  --stop) stop ;;
  --status) status ;;
  --serve) serve ;;
  *) echo "usage: $0 --start|--stop|--status|--serve";;
esac
SH
chmod +x "$TOOLS/core_web.sh"

# --- 3) LaunchAgent with env -------------------------------------------------
PL="$HOME/Library/LaunchAgents/com.brock.dashboard.http.plist"
cat > "$PL" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.brock.dashboard.http</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>source "$HOME/.config/brock_core/core.env"; CORE_DASH_PORT="${CORE_DASH_PORT:-7780}" CORE_TOKEN="$CORE_TOKEN" ~/Projects/devnotes/tools/core_web.sh --serve</string>
  </array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${HOME}/.local/state/brock_core/dashboard_http.out</string>
  <key>StandardErrorPath</key><string>${HOME}/.local/state/brock_core/dashboard_http.err</string>
</dict></plist>
PLIST

launchctl unload "$PL" 2>/dev/null || true
launchctl load "$PL"

# --- 4) Docs + commit --------------------------------------------------------
cat > "$ROOT/docs/core_suite.md" <<'MD'
# Brock Core OS — Core Suite (Actions + Auth)
- Web: `http://localhost:7780`  | JSON: `/api/status`
- Actions (auth required, header `Authorization: Bearer CORE_TOKEN`):
  - `/api/run?cmd=aiwatch_once` | `/api/run?cmd=aiwatch_mute` | `/api/run?cmd=sync`
- Config:
  - GET `/api/config/aiwatcher` → current config
  - POST `/api/config/aiwatcher` JSON: `{NTFY_ENABLED, NTFY_ON_EMPTY, NTFY_INTERVAL_MIN, NTFY_URL, NTFY_TOPIC}`
- Token file: `~/.config/brock_core/core.env`
MD

cd "$ROOT"
git add tools/core_dash_web.py tools/core_web.sh docs/core_suite.md
git commit -m "feat(core-web): add /api/status + /api/run + /api/config with Bearer auth"
git push

echo "Phase 2 installed. Token file: $CONF/core.env"
