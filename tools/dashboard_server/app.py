import os, json, subprocess, pathlib
from flask import Flask, send_from_directory, request, jsonify

app = Flask(__name__, static_folder="static", static_url_path="/")

REPO = os.path.expanduser("~/Projects/devnotes")
BACK = os.path.join(REPO, "backups")
ARCH = os.path.expanduser("~/Library/Application Support/Download_Archive")

ENV = os.environ.copy()
# conservative PATH for launchd context
ENV["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

TOKEN = os.environ.get("DASH_TOKEN","")

def check_auth(req):
    # If no token configured, allow all
    if not TOKEN:
        return True
    # Expect X-Auth: <token>
    return req.headers.get("X-Auth","") == TOKEN

def tail(path, n=12):
    p = pathlib.Path(path)
    if not p.exists(): return ""
    try:
        out = subprocess.run(["/usr/bin/tail","-n",str(n), str(p)], capture_output=True, text=True)
        return out.stdout
    except Exception as e:
        return f"(tail error: {e})"

def run_cmd(cmd):
    """
    Run either a list (no shell) or a string (shell=True) with sane env.
    Always return dict with rc/stdout/stderr.
    """
    try:
        shell = isinstance(cmd, str)
        out = subprocess.run(cmd, capture_output=True, text=True, env=ENV, shell=shell)
        return {"rc": out.returncode, "stdout": out.stdout, "stderr": out.stderr}
    except Exception as e:
        return {"rc": 997, "stdout": "", "stderr": str(e)}

@app.get("/api/token")
def token_view():
    # Only serve token info to localhost
    ra = request.remote_addr or ""
    if ra not in ("127.0.0.1","::1",""):
        return jsonify({"ok": False, "error": "forbidden"}), 403
    return jsonify({"ok": True, "required": bool(TOKEN), "token": TOKEN})

@app.get("/api/status")
def status():
    if not check_auth(request):
        return jsonify({"ok": False, "error": "unauthorized", "rc": 998}), 403

    def lstate(label):
        try:
            out = subprocess.run(
                ["/bin/launchctl","print",f"gui/{os.getuid()}/{label}"],
                capture_output=True, text=True, env=ENV
            )
            lines = []
            for line in out.stdout.splitlines():
                if "state =" in line or "last exit" in line or "Program =" in line:
                    lines.append(line.strip())
            return "; ".join(lines)
        except Exception as e:
            return f"(launchctl error: {e})"

    return jsonify({
        "ok": True,
        "agents": {
            "logsentinel.daily": lstate("com.brock.logsentinel.daily"),
            "downloads.tidy.weekly": lstate("com.brock.downloads.tidy.weekly"),
            "archive.compactor.monthly": lstate("com.brock.archive.compactor.monthly"),
            "append.overview.daily": lstate("com.brock.maintenance.append.overview.daily"),
            "devcli.selfcheck.daily": lstate("com.brock.devcli.selfcheck.daily"),
        },
        "logs": {
            "daily_rotate": tail(os.path.join(BACK, "daily_rotate.log"), 12),
            "tidy_weekly":  tail(os.path.join(ARCH, "_tidy_weekly.log"), 12),
            "compactor":    tail(os.path.join(ARCH, "_compactor_stdout.log"), 12),
            "overview_err": tail(os.path.join(BACK, "overview_append_stderr.log"), 8),
            "selfcheck":    tail(os.path.join(BACK, "devcli_selfcheck.log"), 8),
            "readme_tail":  tail(os.path.join(REPO, "README.md"), 30),
        }
    })

@app.post("/api/run/<task>")
def run_task(task):
    if not check_auth(request):
        return jsonify({"ok": False, "error": "unauthorized", "rc": 998}), 403

    # Always run via zsh to preserve shebangs/locks
    if task == "daily":
        res = run_cmd(["/usr/local/bin/daily_rotate"])
    elif task == "tidy":
        res = run_cmd(["/usr/local/bin/downloads_tidy_weekly"])
    elif task == "compact":
        script = os.path.join(REPO, "tools/maintenance", "archive_compactor.sh")
        res = run_cmd(f'/bin/zsh "{script}"')
    elif task == "overview":
        script = os.path.join(REPO, "tools/maintenance", "maintenance_overview.sh")
        res = run_cmd(f'/bin/zsh "{script}"')
    elif task == "selfcheck":
        script = os.path.join(REPO, "tools/devcli", "devcli_selfcheck.sh")
        res = run_cmd(f'/bin/zsh "{script}"')
    else:
        return jsonify({"ok": False, "error": "unknown task", "rc": -1}), 400

    return jsonify({"ok": res["rc"] == 0, **res})

@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT","8765")))
