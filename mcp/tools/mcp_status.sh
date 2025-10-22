#!/usr/bin/env zsh
set -euo pipefail

BASE="$(cd "$(dirname "${(%):-%x}")/../.." && pwd)"
LOG="$BASE/mcp/logs/init.log"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"

print_section() {
  print -P "\n%F{cyan}$1%f"
  eval "$2"
}

print_section "📂 Path Check" '
  print "Repo: $BASE"
  print "MCP:  $BASE/mcp"
  [[ -f "$BASE/mcp/.env" ]] && print -P "%F{green}.env:%f OK" || print -P "%F{red}.env missing!%f"
  [[ -f "$LOG" ]] && print -P "%F{green}logs:%f OK" || print -P "%F{red}logs missing!%f"
'

print_section "🔍 Git Status" '
  cd "$BASE"
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no git repo")
  print -P "Branch: %F{blue}$BRANCH%f"
  GIT_STATE=$(git status --porcelain 2>/dev/null | wc -l | tr -d " ")
  [[ $GIT_STATE == 0 ]] && print -P "Working tree: %F{green}clean%f" || print -P "Working tree: %F{red}$GIT_STATE changes%f"
'

print_section "🧩 MCP Health" '
  if [[ -f "$LOG" ]]; then
    tail -n 5 "$LOG" | sed "s/^/  /"
  else
    print -P "%F{red}No init log found.%f"
  fi
'

print_section "🕒 Timestamp" 'print "Checked: $NOW"'
print "✅ MCP status check complete."
