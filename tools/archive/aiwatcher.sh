#!/usr/bin/env bash
# AI Watcher — single-file, switch-driven watcher with ntfy throttling
# Brock Core OS: idempotent, logs, config, clean CLI. macOS/zsh-safe.
set -euo pipefail
SCRIPT="$(basename "${BASH_SOURCE[0]:-$0}")"

# ---------- Defaults (overridable by env/CLI) ----------
STATE_DIR="${STATE_DIR:-$HOME/.local/state/aiwatcher}"
CONF_DIR="${CONF_DIR:-$HOME/.config/aiwatcher}"
LOG_FILE="${LOG_FILE:-$STATE_DIR/aiwatcher.log}"
STAMP_FILE="${STAMP_FILE:-$STATE_DIR/lastpush}"
SOURCES_FILE="${SOURCES_FILE:-$CONF_DIR/sources.txt}"
RULES_FILE="${RULES_FILE:-$CONF_DIR/rules.txt}"
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-aiwatcher}"
NTFY_ENABLED="${NTFY_ENABLED:-true}"
NTFY_ON_EMPTY="${NTFY_ON_EMPTY:-false}"
NTFY_INTERVAL_MIN="${NTFY_INTERVAL_MIN:-30}"
SCAN_TIMEOUT="${SCAN_TIMEOUT:-10}"
USER_AGENT="${USER_AGENT:-aiwatcher/1.0}"
LOOP_SLEEP="${LOOP_SLEEP:-300}"

mkdir -p "$STATE_DIR" "$CONF_DIR"

log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >&2; }
die(){ log "ERR: $*"; exit 1; }
require(){ command -v "$1" >/dev/null 2>&1 || die "missing dep: $1"; }

load_env(){ [[ -f "$CONF_DIR/config.env" ]] && set -a && . "$CONF_DIR/config.env" && set +a; }

init_scaffold(){
  [[ -f "$SOURCES_FILE" ]] || cat >"$SOURCES_FILE" <<'S'
# Sources to scan (URLs or local files). One per line. Lines starting with # are ignored.
https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore
S
  [[ -f "$RULES_FILE" ]] || cat >"$RULES_FILE" <<'R'
# Match rules (regex or fixed words), one per line. Empty and # lines ignored.
^__pycache__$
TODO
ai
R
  [[ -f "$CONF_DIR/config.env" ]] || cat >"$CONF_DIR/config.env" <<E
# aiwatcher config
NTFY_URL="$NTFY_URL"
NTFY_TOPIC="$NTFY_TOPIC"
NTFY_ENABLED=$NTFY_ENABLED
NTFY_ON_EMPTY=$NTFY_ON_EMPTY
NTFY_INTERVAL_MIN=$NTFY_INTERVAL_MIN
E
  log "Scaffold ready:"; echo "  $SOURCES_FILE"; echo "  $RULES_FILE"; echo "  $CONF_DIR/config.env"
}

read_rules(){
  # zsh-safe: no mapfile. Build bash array RULES[] manually.
  RULES=()
  [[ -r "$RULES_FILE" ]] || die "rules file missing: $RULES_FILE (run --init)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments and trim trailing spaces
    line="${line%%#*}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    RULES+=("$line")
  done < "$RULES_FILE"
  ((${#RULES[@]})) || die "no rules in $RULES_FILE"
}

should_throttle(){
  local now last minutes
  now=$(date +%s)
  last=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
  minutes=$(( (now - last) / 60 ))
  [[ "$minutes" -lt "${NTFY_INTERVAL_MIN:-0}" ]]
}

notify(){
  local title="$1" body="${2:-}"
  [[ "${NTFY_ENABLED}" == "true" ]] || { log "ntfy disabled"; return 0; }
  should_throttle && { log "throttled: last push < ${NTFY_INTERVAL_MIN}m"; return 0; }
  require curl
  curl -sS \
    -H "Title: ${title}" \
    -H "Tags: terminal" \
    -H "Content-Type: text/plain; charset=utf-8" \
    -d "$body" \
    "${NTFY_URL%/}/${NTFY_TOPIC}" >/dev/null
  date +%s >"$STAMP_FILE"
  log "ntfy sent: $title"
}

scan_once(){
  load_env
  read_rules
  require grep; require sed
  local total_sources=0 total_hits=0 buf="" src hits

  while IFS= read -r src || [[ -n "${src:-}" ]]; do
    src="${src%%#*}"; src="${src%"${src##*[![:space:]]}"}"
    [[ -z "$src" ]] && continue
    total_sources=$((total_sources+1))

    if [[ "$src" =~ ^https?:// ]]; then
      require curl
      buf="$(curl -m "$SCAN_TIMEOUT" -fsSL -A "$USER_AGENT" "$src" || true)"
    else
      [[ -r "$src" ]] || { log "WARN: cannot read $src"; continue; }
      buf="$(cat "$src" || true)"
    fi

    hits=0
    for r in "${RULES[@]}"; do
      [[ -z "$r" ]] && continue
      if echo "$buf" | grep -E -m1 -q "$r"; then
        hits=$((hits+1))
        echo "$(date '+%F %T') HIT [$src] rule: $r" | tee -a "$STATE_DIR/hits.log"
      fi
    done
    total_hits=$((total_hits + hits))
  done < <(sed -E 's/#.*$//' "$SOURCES_FILE")

  echo "sources=${total_sources} hits=${total_hits}"
  if (( total_hits > 0 )); then
    notify "AI Watcher: ${total_hits} picks" "sources=${total_sources}; rules=${#RULES[@]}"
  else
    [[ "${NTFY_ON_EMPTY}" == "true" ]] && notify "AI Watcher: 0 picks" "no matches"
  fi
}

daemon(){
  log "daemon start: loop=${LOOP_SLEEP}s, throttle=${NTFY_INTERVAL_MIN}m"
  while true; do
    scan_once || log "scan error (continuing)"
    sleep "$LOOP_SLEEP"
  done
}

usage(){
  cat <<USG
AI Watcher — switches & throttled ntfy
Usage:
  $SCRIPT --init               # create scaffold (config, sources, rules)
  $SCRIPT --once               # single scan now
  $SCRIPT --daemon             # loop (LOOP_SLEEP=${LOOP_SLEEP}s)
  $SCRIPT --mute               # run once with notifications disabled
  $SCRIPT --quiet              # suppress "0 picks" notifications
  $SCRIPT --verbose            # allow "0 picks" notifications
  $SCRIPT --interval MINS      # override ntfy throttle minutes
  $SCRIPT --set topic=NAME     # set ntfy topic (or url=...)
  $SCRIPT --show               # print effective config
USG
}

show_cfg(){
  cat <<CFG
STATE_DIR=$STATE_DIR
CONF_DIR=$CONF_DIR
LOG_FILE=$LOG_FILE
SOURCES_FILE=$SOURCES_FILE
RULES_FILE=$RULES_FILE
NTFY_URL=$NTFY_URL
NTFY_TOPIC=$NTFY_TOPIC
NTFY_ENABLED=$NTFY_ENABLED
NTFY_ON_EMPTY=$NTFY_ON_EMPTY
NTFY_INTERVAL_MIN=$NTFY_INTERVAL_MIN
LOOP_SLEEP=$LOOP_SLEEP
CFG
}

# ---------- CLI ----------
cmd="${1-}"
case "${cmd:-}" in
  --init) init_scaffold; exit 0 ;;
  --once) scan_once; exit $? ;;
  --daemon) daemon ;;
  --mute) NTFY_ENABLED=false scan_once; exit $? ;;
  --quiet) NTFY_ON_EMPTY=false scan_once; exit $? ;;
  --verbose) NTFY_ON_EMPTY=true scan_once; exit $? ;;
  --interval)
    shift || die "minutes required"
    NTFY_INTERVAL_MIN="${1:?}"
    scan_once; exit $? ;;
  --set)
    shift || die "key=value required"
    kv="${1:?}"
    case "$kv" in
      topic=*) NTFY_TOPIC="${kv#topic=}";;
      url=*)   NTFY_URL="${kv#url=}";;
      *) die "unknown --set $kv";;
    esac
    scan_once; exit $? ;;
  --show) show_cfg; exit 0 ;;
  ""|--help|-h) usage; exit 0 ;;
  *) usage; die "unknown arg: ${cmd}";;
esac
