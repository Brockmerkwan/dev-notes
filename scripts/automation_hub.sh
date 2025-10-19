#!/usr/bin/env bash
# automation_hub.sh — chain your nightly tasks in one go
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "[hub] 1) Defensive audit (FAST)"
bash "$HOME/scripts/run_sys_audit_wrapper.sh" --profile fast || true

echo "[hub] 2) Commit latest summaries"
bash "$HOME/scripts/commit_summaries.sh" || true

echo "[hub] 3) Update living README"
REPO_DIR="${REPO_DIR:-$HOME/Projects/devnotes}"
bash "$REPO_DIR/update_readme.sh" || true

echo "[hub] Done."
