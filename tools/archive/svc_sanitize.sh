#!/usr/bin/env bash
# svc_sanitize.sh — audit/disable stale services on macOS (user scope)
# Features: scan, disable by label, bulk-disable com.brock.*, kill-by-pattern
# Safe: idempotent, --dry-run, quarantine disabled plists to ~/.local/state/disabled-plists
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
LOG_DIR="$HOME/.local/state"
QUAR="$LOG_DIR/disabled-plists"
mkdir -p "$LOG_DIR" "$QUAR"

say(){ printf '%s\n' "$*"; }
run(){ if [[ "$DRY_RUN" = "1" ]]; then say "[dry-run] $*"; else eval "$@"; fi; }
ts(){ date +%Y%m%d-%H%M%S; }

# Paths to search (user scope primary; system scope if sudo)
USER_LA=("$HOME/Library/LaunchAgents")
USER_LD=("$HOME/Library/LaunchDaemons")
SYS_LA=("/Library/LaunchAgents")
SYS_LD=("/Library/LaunchDaemons")

# Read a key from a plist (returns blank on failure)
plist_read() {
  local f="$1" key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$f" 2>/dev/null || true
}

# Find candidate plists (user first; if root, include system)
collect_plists() {
  local arr=()
  for d in "${USER_LA[@]}" "${USER_LD[@]}"; do [[ -d "$d" ]] && arr+=("$d"/*.plist); done
  if [[ $(id -u) -eq 0 ]]; then
    for d in "${SYS_LA[@]}" "${SYS_LD[@]}"; do [[ -d "$d" ]] && arr+=("$d"/*.plist); done
  fi
  printf '%s\n' "${arr[@]}" | awk 'NF && $0 !~ /\*\.plist$|^nil$/'
}

# Resolve the launchctl "domain-target" for bootout/bootstrapping
domain_target() {
  if [[ -n "${SUDO_USER:-}" && "$(id -u)" -eq 0 ]]; then
    # running as root targeting user's GUI session
    local uid; uid="$(id -u "$SUDO_USER")"
    echo "gui/$uid"
  else
    echo "gui/$(id -u)"
  fi
}

bootout_plist() {
  local plist="$1"; local dom; dom="$(domain_target)"
  run "launchctl bootout '$dom' '$plist' 2>/dev/null || launchctl unload '$plist' 2>/dev/null || true"
}

bootstrap_plist() {
  local plist="$1"; local dom; dom="$(domain_target)"
  run "launchctl bootstrap '$dom' '$plist' 2>/dev/null || launchctl load '$plist' 2>/dev/null || true"
}

kill_pattern() {
  local pat="$1"
  say "Killing processes matching: $pat"
  run "pkill -f \"$pat\" || true"
}

# --- Actions ---
scan() {
  say "=== Launchctl (user) running ==="
  launchctl list 2>/dev/null | sed -n '1,200p' | awk 'NR==1 || /com\.brock|watcher|aiwatcher|dashboard|python|node/'
  echo

  say "=== Homebrew services (if present) ==="
  if command -v brew >/dev/null 2>&1; then
    brew services list | awk 'NR==1 || /started|error|aiwatcher|brock|dashboard/'
  else
    say "(brew not found)"
  fi
  echo

  say "=== Plist audit (missing targets / invalid ProgramArguments) ==="
  local any=0
  while IFS= read -r plist; do
    [[ -f "$plist" ]] || continue
    local lbl pg0
    lbl="$(plist_read "$plist" Label)"
    pg0="$(plist_read "$plist" ProgramArguments:0)"
    [[ -z "$lbl" ]] && lbl="$(basename "${plist%.plist}")"
    # Try Program or ProgramArguments
    local prog="$(plist_read "$plist" Program)"
    [[ -z "$prog" ]] && prog="$pg0"
    local status="OK"
    if [[ -z "$prog" ]]; then status="NO_PROGRAM"; fi
    if [[ -n "$prog" && ! -e "$prog" && "$prog" != /* ]]; then status="OK_PATHLESS" # non-absolute path is sometimes fine
    elif [[ -n "$prog" && ! -e "$prog" ]]; then status="MISSING_TARGET"; fi
    printf "%-40s  %-7s  %s\n" "$lbl" "$status" "$plist"
    any=1
  done < <(collect_plists)
  [[ "$any" -eq 1 ]] || say "(no plists found)"
  echo

  say "Tip: use 'Disable by label' to quarantine any with MISSING_TARGET."
}

disable_by_label() {
  local label="${1:-}"
  if [[ -z "$label" ]]; then read -rp "Label to disable (e.g., com.brock.aiwatcher): " label; fi
  [[ -n "$label" ]] || { say "No label provided."; return; }
  say "Searching for plist with Label=$label …"
  local found=
  while IFS= read -r plist; do
    [[ -f "$plist" ]] || continue
    local lbl; lbl="$(plist_read "$plist" Label)"
    [[ "$lbl" == "$label" ]] && { found="$plist"; break; }
  done < <(collect_plists)

  if [[ -z "$found" ]]; then
    say "Label not found in known plist dirs."
    return
  fi
  say "Booting out & quarantining: $found"
  bootout_plist "$found"
  local dst="$QUAR/$(basename "$found").$(ts)"
  run "mv \"$found\" \"$dst\""
  say "Quarantined -> $dst"
}

disable_brock_all() {
  say "Disabling ALL com.brock.* user LaunchAgents/Daemons"
  while IFS= read -r plist; do
    [[ -f "$plist" ]] || continue
    local lbl; lbl="$(plist_read "$plist" Label)"
    [[ "$lbl" =~ ^com\.brock\. ]] || continue
    say "→ $lbl  ($plist)"
    bootout_plist "$plist"
    local dst="$QUAR/$(basename "$plist").$(ts)"
    run "mv \"$plist\" \"$dst\""
  done < <(collect_plists)
  say "Done."
}

menu() {
  while :; do
    echo "------------------------------------------------------------"
    echo "Service Sanitizer (user: $(id -un))  dry-run=$DRY_RUN"
    echo "Quarantine: $QUAR"
    echo "------------------------------------------------------------"
    echo "1) Scan (running + plist audit)"
    echo "2) Disable by label (quarantine)"
    echo "3) Disable ALL com.brock.* (quarantine)"
    echo "4) Kill process by pattern"
    echo "0) Exit"
    read -rp "Select: " c
    case "${c:-}" in
      1) scan ;;
      2) disable_by_label ;;
      3) disable_brock_all ;;
      4) read -rp "Pattern (eg: aiwatcher|dashboard): " p; [[ -n "$p" ]] && kill_pattern "$p" || true ;;
      0) break ;;
      *) echo "Invalid";;
    esac
  done
}

usage(){
  cat <<USAGE
Usage: $(basename "$0") [scan|menu|disable-label <label>|disable-brock-all|kill <pattern>] [--dry-run]
Examples:
  $(basename "$0") scan
  $(basename "$0") disable-label com.brock.aiwatcher
  DRY_RUN=1 $(basename "$0") disable-brock-all
USAGE
}

parse_flags(){
  local out=()
  for a in "$@"; do case "$a" in --dry-run) DRY_RUN=1;; *) out+=("$a");; esac; done
  ARGS=("${out[@]}")
}

main(){
  ARGS=(); parse_flags "$@"
  local cmd="${ARGS[0]:-menu}"
  if [[ "${#ARGS[@]}" -gt 0 ]]; then ARGS=("${ARGS[@]:1}"); fi
  case "$cmd" in
    scan) scan ;;
    disable-label) disable_by_label "${ARGS[0]:-}" ;;
    disable-brock-all) disable_brock_all ;;
    kill) kill_pattern "${ARGS[0]:-}" ;;
    menu) menu ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}
main "$@"
