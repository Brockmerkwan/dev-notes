#!/bin/zsh
set -euo pipefail
R="$HOME/Projects/devnotes"; F="$R/README.md"; A="$HOME/Downloads/_Archive"; B="$R/backups"
mkdir -p "$R"; touch "$F"
ts(){ date '+%Y-%m-%d %H:%M:%S %Z'; }
{
  echo "## Maintenance Snapshot — $(ts)"
  echo
  echo "### LaunchAgents"
  launchctl list | egrep 'logsentinel.daily|downloads.tidy.weekly|archive.compactor.monthly|maintenance.overview.daily' || echo "(none)"
  echo
  echo "### Recent Logs"
  echo "**daily_rotate.log**"; echo '```'; tail -n 10 "$B/daily_rotate.log" 2>/dev/null || echo "(no log)"; echo '```'
  echo "**_tidy_weekly.log**"; echo '```'; tail -n 10 "$A/_tidy_weekly.log" 2>/dev/null || echo "(no log)"; echo '```'
  echo "**_compactor_stdout.log**"; echo '```'; tail -n 10 "$A/_compactor_stdout.log" 2>/dev/null || echo "(no log)"; echo '```'
  echo
} >>"$F"
