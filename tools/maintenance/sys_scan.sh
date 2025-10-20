#!/usr/bin/env bash
# Brock Core OS — System Scan + Auto-Fix/Upgrade (macOS)
# Logs → ~/.local/share/brock/logs
# Memory append → ~/.local/share/brock/memory.md
# NEW: JSON summary → ~/.local/share/brock/reports/sys_scan_<ts>.json

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
MEM_DIR="${MEM_DIR:-$HOME/.local/share/brock}"
LOG_DIR="${LOG_DIR:-$MEM_DIR/logs}"
REP_DIR="${REP_DIR:-$MEM_DIR/reports}"
MEM_FILE="$MEM_DIR/memory.md"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/sys_scan_${TS}.log"
JSON="$REP_DIR/sys_scan_${TS}.json"

mkdir -p "$LOG_DIR" "$REP_DIR"
[[ -f "$MEM_FILE" ]] || { echo "# 🧠 Brock Core OS — Memory Log" > "$MEM_FILE"; echo >> "$MEM_FILE"; }

# ── Defaults (safe) ───────────────────────────────────────────────────────────
AUTO_BREW="${AUTO_BREW:-1}"         # brew upgrade
CLEAN_BREW="${CLEAN_BREW:-1}"       # brew cleanup
AUTO_PIP="${AUTO_PIP:-1}"           # pip3 --user upgrade
AUTO_NPM="${AUTO_NPM:-1}"           # npm -g update
AUTO_GEM="${AUTO_GEM:-0}"           # gem update (off unless brew ruby)
AUTO_OS="${AUTO_OS:-0}"             # softwareupdate -ia (opt-in)
AUTO_JAVA="${AUTO_JAVA:-1}"         # install Temurin if no real JDK
AUTO_RUBY="${AUTO_RUBY:-1}"         # install brew ruby if system ruby < 3
AUTO_DOCKER_PRUNE="${AUTO_DOCKER_PRUNE:-0}"   # docker system prune -f
OPEN_MEMORY="${OPEN_MEMORY:-0}"     # open memory file after run (macOS 'open')

# ── Helpers ───────────────────────────────────────────────────────────────────
has() { command -v "$1" >/dev/null 2>&1; }
log() { printf "%s\n" "$*" | tee -a "$LOG"; }
section() { printf "\n## %s\n" "$*" | tee -a "$LOG"; }
kv() { printf "%-24s %s\n" "$1" "$2" | tee -a "$LOG"; }
n_lines() { wc -l | awk '{print $1}'; }

# Counters / state (for summary + JSON)
OUTDATED_CNT=0; CASK_CNT=0; PIP_CNT=0; NPM_CNT=0; GEM_CNT=0
DISK_WARN=0;    STATUS="ok";  ERRMSG=""

echo "== System Scan ${TS} ==" | tee "$LOG"

# ── System ────────────────────────────────────────────────────────────────────
section "System"
kv "Hostname" "$(scutil --get LocalHostName 2>/dev/null || hostname)"
kv "macOS" "$(sw_vers -productVersion 2>/dev/null || echo N/A)"
kv "Kernel" "$(uname -a | awk '{print $1, $3}')"
kv "Uptime" "$(uptime | sed 's/^.*up //; s/,.*//')"
kv "CPU" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo N/A)"
kv "Memory(GB)" "$(python3 - <<'PY' 2>/dev/null || echo N/A
import subprocess
try:
    print(round(int(subprocess.check_output(['sysctl','-n','hw.memsize']).strip())/1024/1024/1024,1))
except Exception:
    print('N/A')
PY
)"
has sysctl && kv "Swap" "$(sysctl vm.swapusage 2>/dev/null | sed 's/.*= //')"

# Disk
section "Disk"
df -h | tee -a "$LOG"
while read -r line; do
  fs="$(echo "$line" | awk '{print $1}')"
  pct="$(echo "$line" | awk '{print $(NF-1)}' | tr -d '%')"
  mnt="$(echo "$line" | awk '{print $NF}')"
  case "$fs" in devfs|map|procfs|overlay) continue;; esac
  [[ "$pct" =~ ^[0-9]+$ ]] || continue
  if [ "$pct" -ge 95 ]; then
    kv "Disk pressure" "High on ${mnt} (${pct}%)"
    DISK_WARN=1
  fi
done < <(df -h | tail -n +2)

# Versions
section "Toolchain Versions"
has zsh     && kv "zsh" "$(zsh --version)"
has bash    && kv "bash" "$(bash --version | head -1)"
has git     && kv "git" "$(git --version)"
has xcode-select && kv "xcode-select" "$(xcode-select -p 2>/dev/null || echo not-installed)"
has clang   && kv "clang" "$(clang --version | head -1)" || true
has python3 && kv "python3" "$(python3 --version)"
has pip3    && kv "pip3" "$(pip3 --version)"
has node    && kv "node" "$(node -v)"
has npm     && kv "npm" "$(npm -v)"
has ruby    && kv "ruby" "$(ruby -v)"
has gem     && kv "gem" "$(gem --version)"
has java    && kv "java" "$(java -version 2>&1 | head -1 || echo N/A)"
has docker  && kv "docker" "$(docker --version 2>/dev/null || echo N/A)"
has ollama  && kv "ollama" "$(ollama --version 2>/dev/null || echo N/A)"

# ── Fix: Java (real JDK check) ────────────────────────────────────────────────
section "Fix: Java (Temurin)"
if /usr/libexec/java_home -V >/dev/null 2>&1; then
  kv "Java status" "JDK present"
else
  if has brew && [[ "$AUTO_JAVA" == "1" ]]; then
    log "\$ brew install --cask temurin"
    brew install --cask temurin | tee -a "$LOG" || true
    kv "Java status" "$(/usr/libexec/java_home -V 2>&1 | head -n 1 || echo 'installed')"
  else
    kv "Java status" "no JDK; set AUTO_JAVA=1 to install Temurin"
  fi
fi

# ── Fix: Ruby (brew ruby if system ruby < 3) ──────────────────────────────────
RUBY_MAJ="$(ruby -v 2>/dev/null | awk '{print $2}' | cut -d. -f1 || echo 0)"
if [[ "$AUTO_RUBY" == "1" && "$RUBY_MAJ" -gt 0 && "$RUBY_MAJ" -lt 3 ]]; then
  section "Fix: Ruby (Homebrew)"
  if has brew; then
    log "\$ brew install ruby"
    brew install ruby | tee -a "$LOG" || true
    RB_PATH="/opt/homebrew/opt/ruby/bin"
    if [ -d "$RB_PATH" ]; then
      grep -qF "$RB_PATH" "$HOME/.zshrc" 2>/dev/null || {
        echo "export PATH=\"$RB_PATH:\$PATH\"" >> "$HOME/.zshrc"
        kv "Shell" "Appended PATH to ~/.zshrc (open new shell)"
      }
    fi
    kv "ruby" "$("$RB_PATH/ruby" -v 2>/dev/null || ruby -v)"
  else
    kv "Ruby status" "brew not installed — skipped"
  fi
fi

# ── Homebrew ─────────────────────────────────────────────────────────────────
section "Homebrew"
if has brew; then
  log "\$ brew update (quiet)"; brew update >/dev/null 2>&1 || true
  OUTDATED="$(brew outdated || true)"; OUTDATED_CNT="$(printf "%s\n" "$OUTDATED" | n_lines)"
  kv "Brew outdated" "$OUTDATED_CNT"; [[ "$OUTDATED_CNT" -gt 0 ]] && echo "$OUTDATED" | tee -a "$LOG"
  CASK_OUT="$(brew outdated --cask || true)"; CASK_CNT="$(printf "%s\n" "$CASK_OUT" | sed '/^$/d' | n_lines)"
  kv "Cask outdated" "$CASK_CNT"; [[ "$CASK_CNT" -gt 0 ]] && echo "$CASK_OUT" | tee -a "$LOG"
  if [[ "$AUTO_BREW" == "1" ]]; then
    section "Homebrew Upgrade"
    log "\$ brew upgrade"; brew upgrade | tee -a "$LOG" || true
    [[ "$CLEAN_BREW" == "1" ]] && { log "\$ brew cleanup"; brew cleanup | tee -a "$LOG" || true; }
  else
    kv "Brew action" "DRY RUN (set AUTO_BREW=1 to apply)"
  fi
else
  kv "Homebrew" "not installed"
fi

# ── macOS Updates (opt-in) ───────────────────────────────────────────────────
section "macOS Updates"
if has softwareupdate; then
  log "\$ softwareupdate --list"
  softwareupdate --list | tee -a "$LOG" || true
  if [[ "$AUTO_OS" == "1" ]]; then
    log "\$ softwareupdate -ia"
    softwareupdate -ia | tee -a "$LOG" || true
  else
    kv "OS action" "DRY RUN (set AUTO_OS=1 to apply)"
  fi
fi

# ── Python (pip user) ────────────────────────────────────────────────────────
section "Python (pip user)"
if has pip3; then
  PIP_OUT="$(pip3 list --user --outdated --format=columns 2>/dev/null || true)"
  PIP_CNT="$(printf "%s\n" "$PIP_OUT" | awk 'NR>2' | n_lines)"
  kv "pip user outdated" "$PIP_CNT"; [[ "$PIP_CNT" -gt 0 ]] && echo "$PIP_OUT" | tee -a "$LOG"
  if [[ "$AUTO_PIP" == "1" && "$PIP_CNT" -gt 0 ]]; then
    awk 'NR>2 {print $1}' <<<"$PIP_OUT" | while read -r pkg; do
      log "\$ pip3 install --user -U $pkg"
      pip3 install --user -U "$pkg" | tee -a "$LOG" || true
    done
  else
    kv "pip action" "DRY RUN (set AUTO_PIP=1 to apply)"
  fi
else
  kv "pip3" "not installed"
fi

# ── Node (npm -g) — JSON, portable ───────────────────────────────────────────
section "Node (npm -g)"
if has npm; then
  JSON="$(npm -g outdated --json 2>/dev/null || echo '{}')"
  [[ -z "$JSON" || "$JSON" == "null" ]] && JSON="{}"
  NPM_CNT="$(python3 - <<'PY' <<<"$JSON" 2>/dev/null || echo 0
import json,sys
try:
  data=json.load(sys.stdin)
  print(0 if not isinstance(data,dict) else len(data))
except Exception:
  print(0)
PY
)"
  kv "npm -g outdated" "$NPM_CNT"
  [[ "$NPM_CNT" -gt 0 ]] && npm -g outdated 2>/dev/null | tee -a "$LOG" || true
  if [[ "$AUTO_NPM" == "1" && "$NPM_CNT" -gt 0 ]]; then
    log "\$ npm -g update"
    npm -g update | tee -a "$LOG" || true
  else
    kv "npm action" "DRY RUN (set AUTO_NPM=1 to apply)"
  fi
else
  kv "npm" "not installed"
fi

# ── Ruby (gems) — cautious ───────────────────────────────────────────────────
section "Ruby (gems)"
if has gem; then
  GEM_OUT="$(gem outdated 2>/dev/null || true)"
  GEM_CNT="$(printf "%s\n" "$GEM_OUT" | sed '/^$/d' | n_lines)"
  kv "gem outdated" "$GEM_CNT"; [[ "$GEM_CNT" -gt 0 ]] && echo "$GEM_OUT" | tee -a "$LOG"
  RUBY_PATH="$(command -v ruby || echo)"
  if [[ "$AUTO_GEM" == "1" ]] || [[ "$RUBY_PATH" == /opt/homebrew/* ]]; then
    if [[ "$GEM_CNT" -gt 0 ]]; then
      log "\$ gem update"
      gem update | tee -a "$LOG" || true
    fi
  else
    kv "gem action" "SAFE MODE (system Ruby). Set AUTO_GEM=1 or use brew Ruby."
  fi
else
  kv "gem" "not installed"
fi

# ── Optional: Docker prune ────────────────────────────────────────────────────
if [[ "$AUTO_DOCKER_PRUNE" == "1" && "$(docker info >/dev/null 2>&1; echo $?)" -eq 0 ]]; then
  section "Docker"
  log "\$ docker system prune -f"
  docker system prune -f | tee -a "$LOG" || true
fi

# ── Recount after upgrades for accurate summary / JSON ────────────────────────
recount() {
  if has brew; then
    OUTDATED="$(brew outdated || true)"; OUTDATED_CNT="$(printf "%s\n" "$OUTDATED" | n_lines)"
    CASK_OUT="$(brew outdated --cask || true)"; CASK_CNT="$(printf "%s\n" "$CASK_OUT" | sed '/^$/d' | n_lines)"
  fi
  if has pip3; then
    PIP_OUT="$(pip3 list --user --outdated --format=columns 2>/dev/null || true)"
    PIP_CNT="$(printf "%s\n" "$PIP_OUT" | awk 'NR>2' | n_lines)"
  fi
  if has npm; then
    JSON="$(npm -g outdated --json 2>/dev/null || echo '{}')"; [[ -z "$JSON" || "$JSON" == "null" ]] && JSON="{}"
    NPM_CNT="$(python3 - <<'PY' <<<"$JSON" 2>/dev/null || echo 0
import json,sys
try:
  d=json.load(sys.stdin); print(0 if not isinstance(d,dict) else len(d))
except: print(0)
PY
)"
  fi
  if has gem; then
    GEM_OUT="$(gem outdated 2>/dev/null || true)"; GEM_CNT="$(printf "%s\n" "$GEM_OUT" | sed '/^$/d' | n_lines)"
  fi
}
recount

# ── Summary block (safe builder) ──────────────────────────────────────────────
section "Summary"
kv "Brew outdated" "${OUTDATED_CNT:-0}"
kv "Cask outdated" "${CASK_CNT:-0}"
kv "pip user outdated" "${PIP_CNT:-0}"
kv "npm -g outdated" "${NPM_CNT:-0}"
kv "gem outdated" "${GEM_CNT:-0}"

read -r -d '' SUMMARY <<'EOS'
- Auto scan complete (brew=__BREW__, cask=__CASK__, pip=__PIP__, npm=__NPM__, gem=__GEM__)
- Actions (1=applied,0=dry): brew=__AB__, cleanup=__CL__, pip=__AP__, npm=__AN__, gem=__AG__, os=__AO__, java=__AJ__, ruby_fix=__AR__, docker_prune=__DP__
__DISK_WARN_LINE__
Next 1–3 actions:
1) Review log: __LOG__
2) If disk high: sudo du -hxd 1 /Volumes/demoncave | sort -h | tail -n 25
3) (Optional) Enable macOS updates: AUTO_OS=1
EOS

SUMMARY="${SUMMARY/__BREW__/${OUTDATED_CNT:-0}}"
SUMMARY="${SUMMARY/__CASK__/${CASK_CNT:-0}}"
SUMMARY="${SUMMARY/__PIP__/${PIP_CNT:-0}}"
SUMMARY="${SUMMARY/__NPM__/${NPM_CNT:-0}}"
SUMMARY="${SUMMARY/__GEM__/${GEM_CNT:-0}}"
SUMMARY="${SUMMARY/__AB__/$AUTO_BREW}"
SUMMARY="${SUMMARY/__CL__/$CLEAN_BREW}"
SUMMARY="${SUMMARY/__AP__/$AUTO_PIP}"
SUMMARY="${SUMMARY/__AN__/$AUTO_NPM}"
SUMMARY="${SUMMARY/__AG__/$AUTO_GEM}"
SUMMARY="${SUMMARY/__AO__/$AUTO_OS}"
SUMMARY="${SUMMARY/__AJ__/$AUTO_JAVA}"
SUMMARY="${SUMMARY/__AR__/$AUTO_RUBY}"
SUMMARY="${SUMMARY/__DP__/$AUTO_DOCKER_PRUNE}"
if [[ "${DISK_WARN:-0}" -eq 1 ]]; then
  SUMMARY="${SUMMARY/__DISK_WARN_LINE__/- Disk warning: One or more volumes >=95% full. Inspect with: sudo du -hxd 1 /path | sort -h | tail -n 25}"
else
  SUMMARY="${SUMMARY/__DISK_WARN_LINE__/}"
fi
SUMMARY="${SUMMARY/__LOG__/$LOG}"

{
  echo "## $(date '+%Y-%m-%d %H:%M:%S') — sys_scan ${TS}"
  echo
  echo "$SUMMARY"
  echo
} >> "$MEM_FILE"

# ── JSON report for dashboards ────────────────────────────────────────────────
STATUS="ok"
[[ "$DISK_WARN" -eq 1 ]] && STATUS="warn"
cat > "$JSON" <<J
{
  "timestamp": "$TS",
  "hostname": "$(scutil --get LocalHostName 2>/dev/null || hostname)",
  "macos": "$(sw_vers -productVersion 2>/dev/null || echo N/A)",
  "counts": {
    "brew": $OUTDATED_CNT,
    "cask": $CASK_CNT,
    "pip": $PIP_CNT,
    "npm": $NPM_CNT,
    "gem": $GEM_CNT
  },
  "disk_warning": $DISK_WARN,
  "status": "$STATUS",
  "log": "$LOG",
  "memory": "$MEM_FILE"
}
J

# ── Finalize ──────────────────────────────────────────────────────────────────
echo
echo "📝 Log    → $LOG"
echo "🧠 Memory → $MEM_FILE"
echo "📊 JSON   → $JSON"
[[ "$OPEN_MEMORY" == "1" ]] && { open "$MEM_FILE" 2>/dev/null || true; }
echo "✅ Done."
exit 0
