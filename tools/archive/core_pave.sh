#!/usr/bin/env bash
set -euo pipefail

# -------- Paths
ROOT="${HOME}/Projects/devnotes"
LA_DIR="${HOME}/Library/LaunchAgents"
STATE="${HOME}/.local/state"
CONF="${HOME}/.config"
BK="${HOME}/backups/coreos_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BK" "$STATE" "$CONF"

log(){ printf "%s %s\n" "$(date '+%F %T')" "$*"; }
ok(){  printf "✅ %s\n" "$*"; }

# -------- 0) Snapshot important bits
log "Snapshotting current LaunchAgents and configs → $BK"
mkdir -p "$BK/LaunchAgents" "$BK/config"
cp -a "$LA_DIR"/com.brock.*.plist "$BK/LaunchAgents/" 2>/dev/null || true
cp -a "$CONF"/{aiwatcher,brock_core} "$BK/config/" 2>/dev/null || true
ok "Snapshot complete"

# -------- 1) Stop & purge running services
log "Stopping com.brock.* LaunchAgents"
launchctl print "gui/$(id -u)" 2>/dev/null | awk '/com\.brock\./{print $1}' \
  | xargs -I{} bash -lc 'launchctl bootout "gui/$(id -u)"/{} || true'

log "Killing leftover processes"
pkill -f core_dash_web.py 2>/dev/null || true
pkill -f aiwatcher.sh     2>/dev/null || true

# -------- 2) Clean state (archived)
log "Archiving state dirs to $BK"
for d in "$STATE/brock_core" "$STATE/aiwatcher" "$STATE/logsentinel" ; do
  [ -d "$d" ] && mv "$d" "$BK/" || true
done
ok "State cleared"

# -------- 3) Repo: reset to clean release/core-web
log "Syncing repo to remote release/core-web"
mkdir -p "$ROOT"; cd "$ROOT"
git fetch origin
git checkout -B release/core-web origin/release/core-web
git reset --hard origin/release/core-web
ok "Repo at $(git rev-parse --short HEAD)"

# -------- 4) Recreate LaunchAgent (dashboard)
log "Writing fresh LaunchAgent plist"
cat > "$LA_DIR/com.brock.dashboard.http.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0"><dict>
  <key>Label</key><string>com.brock.dashboard.http</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string><string>-lc</string>
    <string>python3 "$HOME/Projects/devnotes/tools/core_dash_web.py"</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CORE_DASH_PORT</key><string>7780</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.local/state/brock_core/dashboard_http.out</string>
  <key>StandardErrorPath</key><string>$HOME/.local/state/brock_core/dashboard_http.err</string>
</dict></plist>
PL

# -------- 5) Fresh token
log "Seeding auth token"
mkdir -p "$CONF/brock_core"
TOKEN=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
cat > "$CONF/brock_core/core.env" <<EOF
CORE_TOKEN="$TOKEN"
CORE_DASH_PORT="7780"
EOF
chmod 600 "$CONF/brock_core/core.env"
ok "Token generated"

# -------- 6) Compile + smoke test on ephemeral port, then enable LaunchAgent
log "Compiling and smoke-testing dashboard"
python3 -m py_compile tools/core_dash_web.py

TEST_PORT=7781 CORE_TOKEN="$TOKEN" CORE_DASH_PORT=7781 \
  python3 tools/core_dash_web.py >/dev/null 2>&1 &
PID=$!
sleep 0.6
C1=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7781/api/status || true)
C2=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" http://127.0.0.1:7781/api/status || true)
kill $PID 2>/dev/null || true
[ "$C1" = "401" ] && [ "$C2" = "200" ] || { echo "Smoke failed $C1/$C2"; exit 1; }
ok "Smoke test passed (401/200)"

# -------- 7) LaunchAgent up
log "Bootstrapping LaunchAgent"
launchctl bootstrap "gui/$(id -u)" "$LA_DIR/com.brock.dashboard.http.plist"
launchctl enable    "gui/$(id -u)/com.brock.dashboard.http"
launchctl kickstart -k "gui/$(id -u)/com.brock.dashboard.http"
ok "Dashboard agent running"

# -------- 8) Final health
log "Health:"
lsof -i :7780 | grep LISTEN || echo "WARN: nothing listening on :7780"
echo "TOKEN=$TOKEN"
ok "Clean install complete"
