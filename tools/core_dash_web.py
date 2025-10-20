#!/usr/bin/env python3
import json, os, subprocess, time, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("CORE_DASH_PORT", "7780"))
CORE_TOKEN = os.environ.get("CORE_TOKEN", "")
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

def check_auth(headers):  # Bearer token for all /api/*
    return (not CORE_TOKEN) or (headers.get("Authorization","") == f"Bearer {CORE_TOKEN}")

# ---- aiwatcher config helpers ------------------------------------------------
CFG_PATH = os.path.expanduser("~/.config/aiwatcher/config.env")

def read_ai_cfg():
    out = {"exists": os.path.exists(CFG_PATH)}
    if not out["exists"]:
        return out
    with open(CFG_PATH) as f:
        for line in f:
            line=line.strip()
            if not line or line.startswith("#"): continue
            k,v=(line.split("=",1)+[""])[:2]
            v=v.strip().strip("'").strip('"')
            out[k]=v
    for k in ("NTFY_ENABLED","NTFY_ON_EMPTY"):
        if k in out: out[k] = str(out[k]).lower() in ("1","true","yes","on")
    if "NTFY_INTERVAL_MIN" in out:
        try: out["NTFY_INTERVAL_MIN"]=int(out["NTFY_INTERVAL_MIN"])
        except: pass
    return out

def write_ai_cfg(payload):
    os.makedirs(os.path.dirname(CFG_PATH), exist_ok=True)
    cur = read_ai_cfg()
    for k in ("NTFY_ENABLED","NTFY_ON_EMPTY","NTFY_INTERVAL_MIN","NTFY_URL","NTFY_TOPIC"):
        if k in payload: cur[k]=payload[k]
    cur["NTFY_ENABLED"] = "true" if str(cur.get("NTFY_ENABLED","")).lower() in ("1","true","yes","on") else "false"
    cur["NTFY_ON_EMPTY"] = "true" if str(cur.get("NTFY_ON_EMPTY","")).lower() in ("1","true","yes","on") else "false"
    try: cur["NTFY_INTERVAL_MIN"]=str(int(cur.get("NTFY_INTERVAL_MIN",30)))
    except: cur["NTFY_INTERVAL_MIN"]="30"
    with open(CFG_PATH,"w") as f:
        f.write("# aiwatcher config (managed by web api)\n")
        for k in ("NTFY_URL","NTFY_TOPIC"):
            if k in cur: f.write(f'{k}="{cur[k]}"\n')
        for k in ("NTFY_ENABLED","NTFY_ON_EMPTY","NTFY_INTERVAL_MIN"):
            if k in cur: f.write(f'{k}={cur[k]}\n')
    return True

# ---- HTML (dark buttons fixed) ----------------------------------------------
HTML = """<!doctype html>
<html><head><meta charset='utf-8'><title>Brock Core OS</title>
<style>
:root{--bg:#0b0f14;--panel:#0f172a;--pane2:#111827;--border:#1f2937;--muted:#9ca3af;--txt:#e6e8eb;--btn:#0f172a;--btnb:#334155}
*{box-sizing:border-box}
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:var(--bg);color:var(--txt)}
h1{margin:0;padding:16px;background:var(--pane2);border-bottom:1px solid var(--border)}
section{padding:16px;border-bottom:1px solid var(--border)}
pre{background:var(--panel);padding:12px;border-radius:6px;overflow:auto}
small{color:var(--muted)}
.btn,button.btn{background:var(--btn);color:var(--txt);border:1px solid var(--btnb);border-radius:6px;padding:8px 12px;display:inline-block;text-decoration:none;font-weight:600;cursor:pointer;margin-right:8px;-webkit-appearance:none;appearance:none}
.btn:hover,button.btn:hover{filter:brightness(1.12)}
input{background:var(--panel);color:var(--txt);border:1px solid var(--btnb);border-radius:6px;padding:6px}
.controls{display:flex;gap:8px;flex-wrap:wrap}
</style>
<script>
let token = localStorage.getItem('core_token')||'';
function setToken(){ token=document.getElementById('t').value.trim(); localStorage.setItem('core_token',token); document.getElementById('toast').textContent='Token set'; setTimeout(()=>toast.textContent='',2000); }
async function call(path,method='GET',body=null){
  const opt={method,headers:{'Authorization':'Bearer '+token}};
  if(body){opt.headers['Content-Type']='application/json'; opt.body=JSON.stringify(body);}
  const r=await fetch(path,opt);
  if(r.status===401){ document.getElementById('toast').textContent='Unauthorized — set token'; setTimeout(()=>toast.textContent='',3000); return null; }
  if(!r.ok){ document.getElementById('toast').textContent='HTTP '+r.status; setTimeout(()=>toast.textContent='',3000); return null; }
  return await r.json();
}
async function reloadNow(){ const j=await call('/api/status'); if(!j) return;
  ts.textContent=j.time; svc.textContent=j.services; watch.textContent=j.watcher; disk.textContent=j.disk; mem.textContent=j.mem; git.textContent=j.git;
}
async function runAction(a){ const j=await call('/api/run?cmd='+a); if(j) { document.getElementById('toast').textContent='OK: '+a; setTimeout(()=>toast.textContent='',1500);} reloadNow(); }
async function loadCfg(){ const j=await call('/api/config/aiwatcher'); if(!j) return;
  en.checked=!!j.NTFY_ENABLED; em.checked=!!j.NTFY_ON_EMPTY; iv.value=j.NTFY_INTERVAL_MIN||30; topic.value=j.NTFY_TOPIC||''; url.value=j.NTFY_URL||'';
}
async function saveCfg(){ const p={NTFY_ENABLED:en.checked,NTFY_ON_EMPTY:em.checked,NTFY_INTERVAL_MIN:parseInt(iv.value||'30',10),NTFY_TOPIC:topic.value,NTFY_URL:url.value};
  const j=await call('/api/config/aiwatcher','POST',p); document.getElementById('toast').textContent = (j&&j.ok)?'Saved':'Save failed'; setTimeout(()=>toast.textContent='',2000);
}
setInterval(reloadNow,15000);
window.onload=()=>{t.value=token; reloadNow(); if(token) loadCfg();};
</script>
</head><body>
<h1>🧠 Brock Core OS — Web Dashboard <small id="ts"></small></h1>
<section class="controls">
  <input id="t" placeholder="Auth token" size="28"/><button class="btn" onclick="setToken()">Set Token</button>
  <a class="btn" href="/api/status" target="_blank">/api/status (JSON)</a>
  <button class="btn" onclick="reloadNow()">Refresh</button>
  <button class="btn" onclick="runAction('aiwatch_once')">Run Watcher Once</button>
  <button class="btn" onclick="runAction('sync')">Git Sync</button>
  <button class="btn" onclick="runAction('restart_web')">Restart Web</button>
  <span id="toast" style="margin-left:8px;color:#93c5fd"></span>
</section>
<section><h2>Services</h2><pre id="svc">loading…</pre></section>
<section><h2>Watcher</h2><pre id="watch">loading…</pre></section>
<section><h2>Storage / Memory</h2><pre id="disk">loading…</pre><pre id="mem">loading…</pre></section>
<section><h2>Git</h2><pre id="git">loading…</pre></section>
<section><h2>AI Watcher Config</h2>
  <label><input type="checkbox" id="en"/> Notifications Enabled</label>
  <label><input type="checkbox" id="em"/> Notify on Empty</label>
  <div><label>Throttle (min) <input id="iv" type="number" min="0" value="30"/></label></div>
  <div><label>Topic <input id="topic" size="18"/></label> <label>URL <input id="url" size="28"/></label></div>
  <button class="btn" onclick="saveCfg()">Save Config</button>
</section>
</body></html>
"""

class H(BaseHTTPRequestHandler):
    def _send(self, code, ctype, body):
        self.send_response(code); self.send_header("Content-Type", ctype); self.end_headers()
        if isinstance(body, str): body=body.encode()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/"):
            if not check_auth(self.headers):
                self._send(401,"application/json",json.dumps({"ok":False,"error":"unauthorized"})); return
            if self.path.startswith("/api/status"):
                self._send(200,"application/json",json.dumps(status())); return
            if self.path.startswith("/api/config/aiwatcher"):
                self._send(200,"application/json",json.dumps(read_ai_cfg())); return
            if self.path.startswith("/api/run"):
                q = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                cmd = (q.get("cmd") or [""])[0]
                M = {
                    "aiwatch_once": f"{DEV}/tools/aiwatcher.sh --once",
                    "aiwatch_mute": f"{DEV}/tools/aiwatcher.sh --mute",
                    "sync": f"cd {DEV} && git fetch --all --prune && (git diff --quiet && git diff --cached --quiet && echo 'clean' || (git add -A && git commit -m \"chore(sync): via web api\" && git push && echo 'pushed'))",
                    "restart_web": "launchctl unload ~/Library/LaunchAgents/com.brock.dashboard.http.plist && launchctl load ~/Library/LaunchAgents/com.brock.dashboard.http.plist && echo 'restarted'",
                }
                shell = M.get(cmd)
                if not shell:
                    self._send(400,"application/json",json.dumps({"ok":False,"error":"unknown action"})); return
                out = sh(shell)
                self._send(200,"application/json",json.dumps({"ok":True,"action":cmd,"output":out})); return
            self._send(404,"application/json",json.dumps({"ok":False,"error":"not found"})); return
        if self.path in ("/","/index.html"):
            self._send(200,"text/html; charset=utf-8",HTML); return
        self._send(404,"text/plain","not found")

    def do_POST(self):
        if not self.path.startswith("/api/"): self._send(404,"text/plain","not found"); return
        if not check_auth(self.headers): self._send(401,"application/json",json.dumps({"ok":False,"error":"unauthorized"})); return
        if self.path.startswith("/api/config/aiwatcher"):
            length = int(self.headers.get("Content-Length","0") or "0")
            data = self.rfile.read(length) if length else b"{}"
            try: payload = json.loads(data.decode("utf-8"))
            except: payload = {}
            ok = write_ai_cfg(payload)
            self._send(200,"application/json",json.dumps({"ok":ok})); return
        self._send(404,"application/json",json.dumps({"ok":False,"error":"not found"}))

class ReuseHTTPServer(HTTPServer):
    allow_reuse_address = True

def main():
    srv = ReuseHTTPServer(("127.0.0.1", PORT), H)
    print(f"[core_dash_web] listening on http://127.0.0.1:{PORT}")
    srv.serve_forever()

if __name__ == "__main__":
    main()
