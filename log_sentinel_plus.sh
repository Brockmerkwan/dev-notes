#!/usr/bin/env zsh
# Log Sentinel PLUS — visual, one-file tool
# Author: ChatGPT
# Version: 1.1.0
# Platform: macOS (zsh), Linux compatible
#
# Features:
#  - Visual menu; no need to remember flags
#  - Rotate specific folders (pre-filled for your devnotes repo)
#  - Rotate a single file or any folder pattern
#  - Keep last N archives (retention)
#  - Compress with gz (default) or zstd if available
#  - Install to PATH (/usr/local/bin) with a friendly name
#  - Show archives list with sizes
#  - Persistent config at ~/.log_sentinel.conf
#
# Safe defaults: set -euo pipefail; single instance lock; write-checks

set -euo pipefail

# -------- colors --------
autoload -Uz colors 2>/dev/null || true
if typeset -f colors >/dev/null; then colors; fi
C0="${reset_color:-}"
C1="${fg[green]:-}"; C2="${fg[yellow]:-}"; C3="${fg[blue]:-}"; C4="${fg[magenta]:-}"; Cx="${fg[red]:-}"

banner() {
  print -P ""
  print -P "%F{magenta}███%f %F{blue}Log Sentinel PLUS%f %F{green}v1.1%f  %F{yellow}— minimal flags, visual menu%f"
  print -P "%F{blue}──────────────────────────────────────────────────────────────%f"
}

note(){ print -P "%F{green}→%f $*"; }
warn(){ print -P "%F{yellow}⚠%f $*"; }
err(){  print -P "%F{red}✖%f $*"; }
ok(){   print -P "%F{green}✔%f $*"; }

# -------- defaults --------
: ${HOME:="${HOME:-$PWD}"}
CONF="${HOME}/.log_sentinel.conf"
# Pre-filled for your layout (adjust via Option 6 in the menu)
DEFAULT_DEVROOT="${HOME}/Projects/devnotes"
DEFAULT_OUTDIR="${DEFAULT_DEVROOT}/backups"
DEFAULT_TROUBLE_DIR="${DEFAULT_DEVROOT}/docs/troubleshooting"
DEFAULT_DAILY_DIR="${DEFAULT_DEVROOT}/daily_logs"
DEFAULT_KEEP=7
DEFAULT_PREFIX_DEV="devnotes"
DEFAULT_PREFIX_DAILY="daily"
DEFAULT_COMPRESS="gz"   # auto switches to zst if available

# -------- single-instance lock --------
LOCK="${TMPDIR:-/tmp}/.log_sentinel_plus.lock"
if ! ( set -o noclobber; echo $$ > "$LOCK" ) 2>/dev/null; then
  pid="$(cat "$LOCK" 2>/dev/null || true)"
  err "Another instance is running (pid=${pid:-?})."
  exit 1
fi
cleanup(){ rm -f "$LOCK" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# -------- load config --------
load_conf(){
  if [[ -f "$CONF" ]]; then
    source "$CONF"
  fi
  # fallbacks
  DEVROOT="${DEVROOT:-$DEFAULT_DEVROOT}"
  OUTDIR="${OUTDIR:-$DEFAULT_OUTDIR}"
  TROUBLE_DIR="${TROUBLE_DIR:-$DEFAULT_TROUBLE_DIR}"
  DAILY_DIR="${DAILY_DIR:-$DEFAULT_DAILY_DIR}"
  KEEP="${KEEP:-$DEFAULT_KEEP}"
  PREFIX_DEV="${PREFIX_DEV:-$DEFAULT_PREFIX_DEV}"
  PREFIX_DAILY="${PREFIX_DAILY:-$DEFAULT_PREFIX_DAILY}"
  COMPRESS="${COMPRESS:-$DEFAULT_COMPRESS}"
}
save_conf(){
  cat > "$CONF" <<EOF
# Log Sentinel PLUS config
DEVROOT=${DEVROOT:q}
OUTDIR=${OUTDIR:q}
TROUBLE_DIR=${TROUBLE_DIR:q}
DAILY_DIR=${DAILY_DIR:q}
KEEP=${KEEP}
PREFIX_DEV=${PREFIX_DEV:q}
PREFIX_DAILY=${PREFIX_DAILY:q}
COMPRESS=${COMPRESS:q}
EOF
  ok "Saved settings to $CONF"
}

# -------- helpers --------
ts(){ date '+%Y%m%d_%H%M%S'; }
have(){ command -v "$1" >/dev/null 2>&1; }
write_check(){ : > "$1/.write_test" && rm -f "$1/.write_test"; }

choose_compressor(){
  # auto-upgrade to zstd if present and chosen
  local c="${COMPRESS}"
  if [[ "$c" = "zst" ]] && ! have zstd; then
    warn "zstd not found; falling back to gz"
    c="gz"
  fi
  if [[ "$c" = "zst" ]]; then
    echo "zst"
  else
    echo "gz"
  fi
}

archive_name(){
  local prefix="$1"
  local t="$(ts)"
  local c="$(choose_compressor)"
  local ext=".tar.gz"
  [[ "$c" = "zst" ]] && ext=".tar.zst"
  echo "${OUTDIR}/${prefix}_${t}${ext}"
}

rotate_dir(){
  local target_dir="$1"
  local pattern="$2"
  local prefix="$3"

  [[ -d "$target_dir" ]] || { err "Not a directory: $target_dir"; return 1; }

  mkdir -p "$OUTDIR"
  write_check "$OUTDIR"

  local arch="$(archive_name "$prefix")"
  local compressor="$(choose_compressor)"

  note "Archiving %F{blue}${target_dir}%f pattern '%F{magenta}${pattern}%f' → %F{green}${arch}%f"
  pushd "$target_dir" >/dev/null
  if [[ "$compressor" = "zst" ]]; then
    tar --zstd -cf "$arch" -- *(.N-.:${~pattern})
  else
    tar -czf "$arch" -- *(.N-.:${~pattern})
  fi
  popd >/dev/null

  ok "Archive created"
  prune_old "$prefix"
}

rotate_file(){
  local target_file="$1"
  local prefix="$2"

  [[ -f "$target_file" ]] || { err "Not a file: $target_file"; return 1; }
  mkdir -p "$OUTDIR"
  write_check "$OUTDIR"

  local dir="$(dirname "$target_file")"
  local base="$(basename "$target_file")"
  local arch="$(archive_name "$prefix")"
  local compressor="$(choose_compressor)"

  note "Archiving single file %F{blue}${target_file}%f → %F{green}${arch}%f"
  pushd "$dir" >/dev/null
  if [[ "$compressor" = "zst" ]]; then
    tar --zstd -cf "$arch" "$base"
  else
    tar -czf "$arch" "$base"
  fi
  : > "$base"   # truncate after archiving
  popd >/dev/null
  ok "Archived and truncated original file"
  prune_old "$prefix"
}

prune_old(){
  local prefix="$1"
  local compressor="$(choose_compressor)"
  local ext="tar.gz"
  [[ "$compressor" = "zst" ]] && ext="tar.zst"
  local pat="${OUTDIR}/${prefix}_*.${ext}"

  local -a arr
  arr=($(ls -1t $pat 2>/dev/null || true))
  [[ "${#arr[@]}" -eq 0 ]] && return 0

  note "Retention: keep last ${KEEP} (found ${#arr[@]})"
  if (( ${#arr[@]} > KEEP )); then
    local prune_list=("${arr[@]:$KEEP}")
    for p in "${prune_list[@]}"; do
      warn "Pruning $p"
      rm -f -- "$p"
    done
  fi
}

list_archives(){
  mkdir -p "$OUTDIR"
  print -P "%F{blue}Archives in $OUTDIR%f"
  if ls -1 "$OUTDIR"/* 1>/dev/null 2>&1; then
    ls -lh "$OUTDIR" | awk '{printf "%-10s  %s\n", $5, $9}'
  else
    warn "No archives yet."
  fi
}

install_self(){
  local dest="/usr/local/bin/logsentinel"
  print -P "%F{yellow}This will copy this script to%f %F{blue}$dest%f and make it executable."
  read -k "yn?Proceed? (y/N) "
  echo
  [[ "${yn:l}" = "y" ]] || { warn "Install canceled."; return 0; }
  sudo cp "$0" "$dest"
  sudo chmod +x "$dest"
  ok "Installed as $dest"
  print -P "Now you can run:  %F{green}logsentinel%f"
}

edit_settings(){
  print -P "%F{blue}Current settings:%f"
  print -P "DEVROOT=$DEVROOT"
  print -P "OUTDIR=$OUTDIR"
  print -P "TROUBLE_DIR=$TROUBLE_DIR"
  print -P "DAILY_DIR=$DAILY_DIR"
  print -P "KEEP=$KEEP"
  print -P "PREFIX_DEV=$PREFIX_DEV"
  print -P "PREFIX_DAILY=$PREFIX_DAILY"
  print -P "COMPRESS=$COMPRESS (gz|zst)"
  print -P "%F{yellow}Enter new values or press Enter to keep current.%f"

  vread(){ local prompt="$1"; local def="$2"; local __res; print -Pn "$prompt [$def]: "; read __res; echo "${__res:-$def}"; }

  DEVROOT="$(vread "DEVROOT" "$DEVROOT")"
  OUTDIR="$(vread "OUTDIR" "$OUTDIR")"
  TROUBLE_DIR="$(vread "TROUBLE_DIR" "$TROUBLE_DIR")"
  DAILY_DIR="$(vread "DAILY_DIR" "$DAILY_DIR")"
  KEEP="$(vread "KEEP" "$KEEP")"
  PREFIX_DEV="$(vread "PREFIX_DEV" "$PREFIX_DEV")"
  PREFIX_DAILY="$(vread "PREFIX_DAILY" "$PREFIX_DAILY")"
  COMPRESS="$(vread "COMPRESS (gz|zst)" "$COMPRESS")"

  save_conf
}

rotate_any_folder(){
  print -Pn "Folder path: "; read folder
  [[ -d "$folder" ]] || { err "Not a directory"; return 1; }
  print -Pn "Glob pattern (e.g. *.log) [*.log]: "; read pattern; pattern="${pattern:-*.log}"
  print -Pn "Prefix [custom]: "; read pref; pref="${pref:-custom}"
  rotate_dir "$folder" "$pattern" "$pref"
}

rotate_any_file(){
  print -Pn "File path: "; read f
  [[ -f "$f" ]] || { err "Not a file"; return 1; }
  print -Pn "Prefix [single]: "; read pref; pref="${pref:-single}"
  rotate_file "$f" "$pref"
}

main_menu(){
  while true; do
    clear
    banner
    print -P "%F{cyan}Devnotes shortcuts%f (pre-filled for your repo)"
    print -P "  1) Rotate %F{green}Troubleshooting%f logs → ${TROUBLE_DIR}"
    print -P "  2) Rotate %F{green}Daily%f logs → ${DAILY_DIR}"
    print -P "  3) Rotate %F{blue}ANY folder%f (pattern)"
    print -P "  4) Rotate %F{blue}ONE file%f"
    print -P "  5) List archives in ${OUTDIR}"
    print -P "  6) Edit settings & save"
    print -P "  7) Install command to PATH (logsentinel)"
    print -P "  8) Exit"
    print -Pn "Select: "; read pick

    case "$pick" in
      1) rotate_dir "$TROUBLE_DIR" "*.md" "$PREFIX_DEV"; read -k "?(any key)";;
      2) rotate_dir "$DAILY_DIR" "*.md" "$PREFIX_DAILY"; read -k "?(any key)";;
      3) rotate_any_folder; read -k "?(any key)";;
      4) rotate_any_file; read -k "?(any key)";;
      5) list_archives; read -k "?(any key)";;
      6) edit_settings; sleep 1;;
      7) install_self; read -k "?(any key)";;
      8) clear; exit 0;;
      *) warn "Invalid choice"; sleep 1;;
    esac
  done
}

# -------- entry --------
load_conf
mkdir -p "$OUTDIR"
main_menu
