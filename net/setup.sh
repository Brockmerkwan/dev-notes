#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="$HOME/.local/state/netfw"
LOG_FILE="$LOG_DIR/setup_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"

echo "=== 🧩 Network Setup Start: $(date) ===" | tee -a "$LOG_FILE"

# Detect interfaces
echo "[*] Detecting network interfaces..." | tee -a "$LOG_FILE"
ifconfig | grep -E '^[a-z0-9]+' | awk '{print $1}' | tee -a "$LOG_FILE"

# Detect and log active IPs
echo "[*] Active IP assignments:" | tee -a "$LOG_FILE"
ipconfig getifaddr en0 2>/dev/null && echo "LAN: $(ipconfig getifaddr en0)" | tee -a "$LOG_FILE"
ipconfig getifaddr en1 2>/dev/null && echo "2nd NIC: $(ipconfig getifaddr en1)" | tee -a "$LOG_FILE"

# Verify network reachability
echo "[*] Testing gateway + internet reachability..." | tee -a "$LOG_FILE"
ping -c 2 1.1.1.1 | tee -a "$LOG_FILE" || echo "⚠️  Internet not reachable" | tee -a "$LOG_FILE"

# Optional LAN speed test (requires iperf3)
if command -v iperf3 >/dev/null 2>&1; then
  echo "[*] iperf3 installed — run 'iperf3 -s' on one Mac Mini and 'iperf3 -c <ip>' on the other to test speeds." | tee -a "$LOG_FILE"
else
  echo "[*] iperf3 not found — install with: brew install iperf3" | tee -a "$LOG_FILE"
fi

# Git sync (optional)
if [ -d "$HOME/Projects/devnotes/.git" ]; then
  echo "[*] Committing network log to devnotes repo..." | tee -a "$LOG_FILE"
  cp "$LOG_FILE" "$HOME/Projects/devnotes/net/"
  cd "$HOME/Projects/devnotes"
  git add net/
  git commit -m "net(setup): initial network baseline log $(date +%F)"
  git push || echo "⚠️ Git push skipped or failed"
fi

echo "=== ✅ Network Setup Complete: $(date) ===" | tee -a "$LOG_FILE"
