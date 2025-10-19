#!/usr/bin/env bash
set -euo pipefail

# === 🧠 Brock Core OS — Menu Launcher ===
MODEL="brock-core-os"
ENV_FILE="$HOME/.brock_env"

# Optional env
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

banner() {
  clear
  echo "🧠 Brock Core OS — Local AI"
  echo "Model: $MODEL"
  echo "User : ${USER_NAME:-Brock}"
  echo "Repo : ${PROJECTS_DIR:-unset}"
  echo "===================================="
}

ask() {
  # $1 = prompt string (can be multiline)
  # Uses ollama run one-shot prompt
  printf "%s\n" "$1" | ollama run "$MODEL"
}

pause() { read -rp $'\n[Enter] to continue...'; }

devops_menu() {
  while true; do
    banner
    echo "DevOps"
    echo "  1) System scan + 1 maintenance task"
    echo "  2) Git commit message from diff"
    echo "  3) Summarize errors in latest logs"
    echo "  4) Back"
    read -rp $'\nSelect: ' c
    case "$c" in
      1)
        ask "Act as a senior DevOps mentor. Output:
- 3-line system scan checklist for macOS shell environment
- One actionable maintenance task with exact command(s)
- Only mechanical summaries (✅/⚠️/❌)."
        pause;;
      2)
        banner
        REPO="${PROJECTS_DIR:-$HOME/Projects/devnotes}"
        cd "$REPO" || { echo "❌ Repo path missing: $REPO"; pause; continue; }
        echo "⚙️ Running: git diff --staged || git diff"
        DIFF="$(git diff --staged || git diff || true)"
        if [[ -z "$DIFF" ]]; then
          echo "⚠️ No changes detected."
        else
          ask "Create a clear, conventional commit message for this diff.
Rules:
- type(scope): subject
- one concise body line if helpful
- no emojis
---- DIFF START ----
$DIFF
---- DIFF END ----"
        fi
        pause;;
      3)
        banner
        LOG_DIR="${LOG_DIR:-$HOME/.local/share/brock/logs}"
        LAST_LOG="$(ls -1t "$LOG_DIR" 2>/dev/null | head -n1 || true)"
        if [[ -z "$LAST_LOG" ]]; then
          echo "⚠️ No logs found in $LOG_DIR"
          pause; continue
        fi
        ask "Read the following log and output:
- Top 3 errors with terse cause + fix (1 line each)
- One-line root-cause hypothesis
- One verification command list (max 3)
---- LOG START ($LAST_LOG) ----
$(sed -n '1,400p' "$LOG_DIR/$LAST_LOG")
---- LOG END ----"
        pause;;
      4) break;;
      *) :;;
    esac
  done
}

creative_menu() {
  while true; do
    banner
    echo "Creative Writing"
    echo "  1) Story seed (dark metal aesthetic)"
    echo "  2) Rewrite paragraph for flow (paste inline)"
    echo "  3) Back"
    read -rp $'\nSelect: ' c
    case "$c" in
      1)
        ask "Write a 150-word story seed in a dark metal, poetic style.
Constraints:
- vivid sensory detail
- one striking metaphor
- end with a hook question."
        pause;;
      2)
        echo "Paste your paragraph, end with Ctrl-D:"
        TEXT="$(cat)"
        ask "Rewrite for smoother flow, keep voice and meaning. Inline edited result only:
---- TEXT START ----
$TEXT
---- TEXT END ----"
        pause;;
      3) break;;
      *) :;;
    esac
  done
}

kb_menu() {
  while true; do
    banner
    echo "Knowledgebase (DevNotes)"
    echo "  1) Generate LESSON.md outline from a topic"
    echo "  2) Convert shell session to a clean HOWTO"
    echo "  3) Back"
    read -rp $'\nSelect: ' c
    case "$c" in
      1)
        read -rp "Topic: " TOPIC
        ask "Produce a markdown LESSON.md outline for '$TOPIC' with:
- Objectives bullets
- Prereqs (tools/versions)
- Step-by-step (numbered)
- Verification checks
- Expected outputs
- Git commit message line."
        pause;;
      2)
        echo "Paste your shell transcript, end with Ctrl-D:"
        LOGTXT="$(cat)"
        ask "Convert this noisy shell log into a clean HOWTO.md:
- numbered steps
- commands in code blocks
- minimal narration
- 'Verification' and 'Expected success output' sections
- final 'git commit' message
---- LOG START ----
$LOGTXT
---- LOG END ----"
        pause;;
      3) break;;
      *) :;;
    esac
  done
}

repl_menu() {
  banner
  echo "Interactive chat — type. Ctrl-C to exit."
  echo "----------------------------------------"
  ollama run "$MODEL"
}

ensure_dirs() {
  mkdir -p "${LOG_DIR:-$HOME/.local/share/brock/logs}"
}

main_menu() {
  ensure_dirs
  while true; do
    banner
    echo "Main Menu"
    echo "  1) DevOps"
    echo "  2) Creative Writing"
    echo "  3) Knowledgebase"
    echo "  4) Interactive Chat (REPL)"
    echo "  5) Exit"
    read -rp $'\nSelect: ' choice
    case "$choice" in
      1) devops_menu;;
      2) creative_menu;;
      3) kb_menu;;
      4) repl_menu;;
      5) echo "✅ Exit"; exit 0;;
      *) :;;
    esac
  done
}

main_menu
