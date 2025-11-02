#!/usr/bin/env zsh
set -euo pipefail

echo "🧠 Rebuilding README.md for Brock Core OS…"
readme="$HOME/Projects/devnotes/README.md"

cat > "$readme" <<'MD'
# 🧠 Brock Core OS — DevNotes Suite

> Stable build: **v1.0.5-core-health-stable**  
> Runtime: macOS · zsh · Homebrew · Ollama · GitHub Automation

![SYSTEM:ONLINE](https://img.shields.io/badge/SYSTEM-ONLINE-00FFC8?style=for-the-badge&logo=github)
![AUTOMATION:ACTIVE](https://img.shields.io/badge/AUTOMATION-SUITE_ACTIVE-7C3AED?style=for-the-badge)
![DEFENSE:OK](https://img.shields.io/badge/DEFENSE-NETRUNNER_OK-39FF14?style=for-the-badge)
![LESSON_TRACK](https://img.shields.io/badge/LESSON_TRACK-LEVEL_II-FF2E97?style=for-the-badge)
![STATUS:STABLE](https://img.shields.io/badge/STATUS-STABLE-0F0F0F?style=for-the-badge)

---

## ⚙️ System Overview
- **Core Script:** `core.sh` → boot, health, sync, tidy  
- **Visual UX:** `ux_progress.sh` → live progress bar + elapsed time  
- **Logger:** `brock_log()` → replaces macOS `log` CLI conflict  
- **State Logs:** stored in `~/.local/state/brock_core/`  
- **Tools:** auto-patchers for syntax, spinner, and logger injection  

---

## 🚀 Quick Usage
```bash
cd ~/Projects/devnotes
./core.sh --health      # run system health check
./core.sh --sync        # commit + push changes
./core.sh --tidy-now    # clean Downloads + rotate logs
cd ~/Projects/devnotes
git add README.md
git commit -m "docs(readme): refresh for core v1.0.5 stable release"
git push

echo "✅ README refreshed and pushed to GitHub."
