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
