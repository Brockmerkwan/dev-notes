#!/usr/bin/env bash
# sys_audit.sh — Lesson 2: System Health & Audit (macOS + Linux friendly)
# Purpose: Collect a quick, readable system + security baseline into daily_logs/.
# Usage: run from inside your repo root (or any subfolder within the repo).
set -euo pipefail

# Find repo root (or use current dir if not a git repo)
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
else
  REPO_ROOT="$(pwd)"
fi
cd "$REPO_ROOT"
mkdir -p daily_logs

TS="$(date '+%F_%H-%M-%S')"
OUT="daily_logs/$(date '+%F')_sys_audit.txt"

# Pretty header
{
  echo "========================================"
  echo " SYSTEM HEALTH & AUDIT — ${TS}"
  echo " Repo: $REPO_ROOT"
  echo "========================================"
} > "$OUT"

# Helper to run commands safely without breaking the script
run() {
  local title="$1"; shift
  echo -e "\n--- ${title} ---" | tee -a "$OUT"
  if "$@" >>"$OUT" 2>&1; then
    : # success
  else
    echo "[warn] '${title}' failed (command: $*)" >>"$OUT"
  fi
}

# Common
run "Datetime" date
run "User" whoami
run "Uptime" uptime
run "Kernel / Arch" uname -a
run "Disk (root)" df -h /

OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  # macOS
  run "macOS Version" sw_vers
  run "Hardware (mini)" system_profiler SPHardwareDataType -detailLevel mini
  run "Software (mini)" system_profiler SPSoftwareDataType -detailLevel mini
  run "Memory Pressure" memory_pressure
  run "VM Stats" vm_stat
  run "Network (ifconfig brief)" ifconfig
  run "Brew Version" brew -v
  run "Brew Outdated" brew outdated
  run "Firewall (socketfilterfw global state)" /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
  run "Firewall (socketfilterfw stealth + logging)" /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
  run "Tailscale Status" tailscale status
  run "Top Processes (ps aux head)" bash -lc "ps aux | head -n 30"
else
  # Linux
  run "OS Release" bash -lc 'cat /etc/os-release || lsb_release -a'
  run "CPU Info (first lines)" bash -lc 'cat /proc/cpuinfo | head -n 20'
  run "Memory" free -h
  run "Network Listeners" bash -lc 'ss -tulpen || netstat -tulpen'
  run "UFW Status" bash -lc 'ufw status || true'
  run "FirewallD Status" bash -lc 'firewall-cmd --state || true'
  run "Docker Containers" bash -lc 'docker ps'
  run "Top Processes (ps aux head)" bash -lc "ps aux | head -n 30"
  run "Tailscale Status" tailscale status
  run "Recent Critical Logs" bash -lc 'journalctl -p 3 -n 50 || true'
fi

echo -e "\nSaved audit to: $OUT"
echo "✅ sys_audit complete."
