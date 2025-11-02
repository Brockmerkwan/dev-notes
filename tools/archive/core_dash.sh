#!/usr/bin/env bash
# Core Dashboard — quick status view
set -euo pipefail
STATE="$HOME/.local/state"
printf "\n🧠 Brock Core OS — Dashboard\n"
printf "───────────────────────────────\n"

printf "\n[ Services ]\n"
launchctl list | grep brock || echo "No LaunchAgents active."

printf "\n[ Watcher Status ]\n"
LOG="$STATE/aiwatcher/aiwatcher.log"
if [[ -s "$LOG" ]]; then
  tail -n 5 "$LOG"
else
  echo "No watcher log yet."
fi

printf "\n[ Storage / Memory ]\n"
df -h / | awk 'NR==1||NR==2'
vm_stat | awk '/free/ {print "Free RAM pages: "$3}'

printf "\n[ Git Sync Status ]\n"
cd ~/Projects/devnotes
git status -sb || echo "Git status unavailable"

printf "\n✅ Dashboard complete\n"
