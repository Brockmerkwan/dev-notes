#!/usr/bin/env python3
import json, os, subprocess, time, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

# ---------- Config ----------
PORT      = int(os.environ.get("CORE_DASH_PORT", "7780"))
DEV       = os.path.expanduser("~/Projects/devnotes")
STATE_DIR = os.path.expanduser("~/.local/state/brock_core")
CONF_FILE = os.path.expanduser("~/.config/brock_core/core.env")
os.makedirs(STATE_DIR, exist_ok=True)

def _load_token():
    t = os.environ.get("CORE_TOKEN", "").strip()
    if t: return t
    try:
        with open(CONF_FILE) as f:
            for line in f:
                line=line.strip()
                if not line or line.startswith("#"): continue
                k,v = (line.split("=",1)+[""])[:2]
                if k.strip()=="CORE_TOKEN":
                    return v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return ""
CORE_TOKEN = _load_token()

# ---------- Shell ----------
def sh(cmd, timeout=15):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        return out.rstrip()
    except subprocess.CalledProcessError as e:
        return e.output.rstrip()
    except Exception as e:
        return f"ERR: {e}"

def status_payload():
    return {
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "services": sh("launchctl list | awk '$3 ~ /^com\\.brock\\./ {printf(\"%s\\t%s\\t%s\\n\", $1? $1:\"-\", $2? $2:\"-\", $3)}'"),
        "watcher":  sh("tail -n 20 ~/.local/state/aiwatcher/aiwatcher.log 2>/dev/null || echo 'no log'"),
        "disk":     sh("df -h / | awk 'NR==1||NR==2'"),
        "mem":      sh("vm_stat | awk '/free|active|inactive|wired/ {print}'"),
        "git":      sh(f"cd '{DEV}' && git status -sb 2>/dev/null || echo 'git unavailable'"),
    }

def git_info():
    ahead = behind = 0
    ab = sh(f"cd '{DEV}' && git status -b --porcelain=2 2>/dev/null | sed -n 's/^# branch.ab  *\\([0-9]*\\)  *\\([0-9]*\\)$/\\1 \\2/p'")
    try:
        p = ab.split()
        if len(p) >= 2:
            ahead, behind = int(p[0]), int(p[1])
    except Exception:
        pass
    return {"ok": True, "in_sync": ahead==0 and behind==0, "ahead": ahead, "behind": behind}

def run_action(cmd):
    if cmd == "aiwatch_once":
        return sh(f"'{DEV}/tools/aiwatcher.sh' --once", timeout=60)
    if cmd == "aiwatch_mute":
        return sh(f"'{DEV}/tools/aiwatcher.sh' --mute", timeout=60)
    if cmd == "sync":
        return sh(
            f"cd '{DEV}' && git fetch --all --prune >/dev/null 2>&1 || true; "
            "(git diff --quiet && git diff --cached --quiet && echo clean) "
            "|| (git add -A && git commit -m 'chore(sync): via web api' && git push && echo pushed)",
            timeout=120,
        )
    if cmd == "restart_web":
        return sh("launchctl kickstart -k gui/$(id -u)/com.brock.dashboard.http") or "restarted"
    if cmd == "triage":
        tri = os.path.join(DEV, "tools", "error_triage.sh")
        _out = sh(f"'{tri}' --scan", timeout=20)
        return _out if _out.strip() else 'triage: no findings'
    return f"unknown action: {cmd}"

# ---------- Auth ----------
def check_auth(headers):
    if not CORE_TOKEN:
        return False
    return headers.get("Authorization", "") == f"Bearer {CORE_TOKEN}"

# ---------- UI ----------
HTML = """<!doctype html><html><head><meta charset='utf-8'/>
<title>Brock Core OS — Web Dashboard</title>
<style>
body{background:#0b1220;color:#d1e1ff;font-family:-apple-system,system-ui,Segoe UI,Roboto,Ubuntu,Calibri,sans-serif;margin:0}
header{padding:12px 16px;position:sticky;top:0;background:#0b1220;border-bottom:1px solid #1f2937}
h1{margin:0;font-size:18px}
.toolbar button,.toolbar input{background:#0f172a;border:1px solid #334155;color:#e5e7eb;padding:6px 10px;border-radius:6px;margin-right:6px}
.toolbar input{width:220px}
.badge{padding:6px 10px;border:1px solid #334155;border-radius:6px;margin-left:8px}
.badge.ok{border-color:#14532d;color:#86efac}.badge.warn{border-color:#854d0e;color:#facc15}.badge.err{border-color:#7f1d1d;color:#fca5a5}
section{padding:14px 16px}.box{background:#0f172a;border:1px solid #1f2937;border-radius:8px;padding:8px 10px;white-space:pre;overflow:auto}
.label{opacity:.7;margin-bottom:6px}.toast{position:fixed;right:16px;bottom:16px;background:#0f172a;border:1px solid #334155;color:#e5e7eb;padding:8px 12px;border-radius:8px;display:none}
</style></head><body>
<header>
  <h1>🧠 Brock Core OS — Web Dashboard
    <span id="git_badge" class="badge warn">INIT</span>
    <span id="auth_badge" class="badge err">NO TOKEN</span>
  </h1>
  <div class="toolbar">
    <input id="tok" placeholder="Auth token"/><button onclick="setTok()">Set Token</button>
    <button onclick="openJson('/api/status')">/api/status</button>
    <button onclick="openJson('/api/git')">/api/git</button>
    <button onclick="reloadNow()">Refresh</button>
    <button onclick="run('aiwatch_once')">Run Watcher Once</button>
    <button onclick="run('sync')">Git Sync</button>
    <button onclick="run('restart_web')">Restart Web</button>
    <button onclick="run('triage')">Triage Errors</button>
  </div>
</header>
<section><div class="label">Services</div><div id="services" class="box">loading…</div></section>
<section><div class="label">Watcher</div><div id="watcher" class="box">loading…</div></section>
<section><div class="label">Storage / Memory</div><div id="disk" class="box">loading…</div><div id="mem" class="box" style="margin-top:8px">loading…</div></section>
<section><div class="label">Git</div><div id="git" class="box">loading…</div></section>
<div id="toast" class="toast"></div>
<script>
const LS='core_token'; let TOKEN = localStorage.getItem(LS)||''; document.getElementById('tok').value = TOKEN;
function badge(id,text,cls){ const el=document.getElementById(id); el.textContent=text; el.className='badge '+cls; }
function toast(msg){ const t=document.getElementById('toast'); t.textContent=msg; t.style.display='block'; setTimeout(()=>t.style.display='none',1800); }
function hdr(){ return TOKEN? {'Authorization':'Bearer '+TOKEN} : {}; }
function setTok(){ TOKEN=(document.getElementById('tok').value||'').trim(); if(!TOKEN){ badge('auth_badge','NO TOKEN','err'); localStorage.removeItem(LS); toast('Token cleared'); return; } localStorage.setItem(LS,TOKEN); badge('auth_badge','TOKEN SET','ok'); toast('Token saved'); reloadNow(); }
function openJson(u){ window.open(u,'_blank'); }
async function call(url,opts={}){ opts.headers=Object.assign({},opts.headers||{},hdr()); try{ const r=await fetch(url,opts); if(r.status===401){ badge('auth_badge','UNAUTHORIZED','err'); return null; } if(!r.ok) return null; return await r.json(); } catch(e){ return null; } }
async function reloadNow(){ const j=await call('/api/status'); if(!j) return; services.textContent=j.services||''; watcher.textContent=j.watcher||''; disk.textContent=j.disk||''; mem.textContent=j.mem||''; git.textContent=j.git||''; const g=await call('/api/git'); if(g&&g.ok){ if(g.in_sync) badge('git_badge','IN SYNC','ok'); else if(g.ahead>0) badge('git_badge','AHEAD +'+g.ahead,'warn'); else badge('git_badge','BEHIND '+g.behind,'err'); } }
async function run(name){ const r=await call('/api/run?cmd='+encodeURIComponent(name)); if(r&&r.ok){ toast(r.output||'ok'); reloadNow(); } }
if(TOKEN) badge('auth_badge','TOKEN SET','ok'); else badge('auth_badge','NO TOKEN','err'); reloadNow();
</script></body></html>
"""

# ---------- HTTP ----------
class H(BaseHTTPRequestHandler):
    def _send(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.wfile.write(body)

    def do_GET(self):
        p = self.path
        if p == "/":
            self._send(200, "text/html; charset=utf-8", HTML)
            return

        # unauth health probe (only)
        if p.startswith("/api/health"):
            self._send(200, "application/json", json.dumps({"ok": True, "ts": time.time()}))
            return

        # everything under /api/* requires auth
        if p.startswith("/api/"):
            if not check_auth(self.headers):
                self._send(401, "application/json", json.dumps({"ok": False, "error": "unauthorized"}))
                return

            if p.startswith("/api/status"):
                self._send(200, "application/json", json.dumps({"ok": True, **status_payload()}))
                return

            if p.startswith("/api/git"):
                self._send(200, "application/json", json.dumps(git_info()))
                return

            if p.startswith("/api/run"):
                q = urllib.parse.parse_qs(urllib.parse.urlparse(p).query)
                out = run_action((q.get("cmd") or [""])[0])
                self._send(200, "application/json", json.dumps({"ok": True, "output": out}))
                return

            self._send(404, "application/json", json.dumps({"ok": False, "error": "not found"}))
            return

        self._send(404, "text/plain", "not found")

    def do_POST(self):
        p = self.path
        if not p.startswith("/api/"):
            self._send(404, "text/plain", "not found"); return
        if not check_auth(self.headers):
            self._send(401, "application/json", json.dumps({"ok": False, "error": "unauthorized"})); return
        if p.startswith("/api/config/aiwatcher"):
            try:
                l = int(self.headers.get("Content-Length", "0") or "0")
                data = self.rfile.read(l) if l else b"{}"
                payload = json.loads(data.decode("utf-8")) if data else {}
            except Exception:
                payload = {}
            ok = write_ai_cfg(payload)
            self._send(200, "application/json", json.dumps({"ok": ok})); return
        self._send(404, "application/json", json.dumps({"ok": False, "error": "not found"}))

def write_ai_cfg(p):
    confd = os.path.expanduser("~/.config/aiwatcher")
    os.makedirs(confd, exist_ok=True)
    envp = os.path.join(confd, "config.env")
    def _b(v, d):
        if isinstance(v, bool): return "true" if v else "false"
        return str(v if v is not None else d)
    cur = {
        "NTFY_ENABLED":      _b(p.get("NTFY_ENABLED"), "true"),
        "NTFY_ON_EMPTY":     _b(p.get("NTFY_ON_EMPTY"), "false"),
        "NTFY_INTERVAL_MIN": _b(p.get("NTFY_INTERVAL_MIN"), "30"),
        "NTFY_URL":           p.get("NTFY_URL") or "https://ntfy.sh",
        "NTFY_TOPIC":         p.get("NTFY_TOPIC") or "aiwatcher",
    }
    with open(envp, "w") as f:
        for k,v in cur.items():
            f.write(f"{k}={v}\n")
    return True

class Reuse(HTTPServer):
    allow_reuse_address = True

def main():
    srv = Reuse(("127.0.0.1", PORT), H)
    print(f"[core_dash_web] listening on http://127.0.0.1:{PORT}", flush=True)
    srv.serve_forever()

if __name__ == "__main__":
    main()
