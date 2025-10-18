# Lesson 1 — Applied Automation: DevTools & Repo Scripts
**Date:** 2025-10-18  
**User:** Brock Merkwan

## Summary
- Installed global DevTools suite (`repo_sync.sh`, `repo_backup.sh`, `repo_all.sh`) to `~/scripts` and added to `$PATH`.
- Verified operation inside `~/Desktop/devnotes` repo.
- Pushed synchronized changes to GitHub and created timestamped backup archives in `~/DevBackups/devnotes/`.

## Evidence (condensed from terminal)
- Unpacked suite and updated PATH:
  ```bash
  mkdir -p ~/scripts
  unzip ~/Downloads/devtools_suite.zip -d ~/scripts
  chmod +x ~/scripts/repo_*.sh
  echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.zshrc
  source ~/.zshrc
  ```

- Aliases added for quick use:
  ```bash
  alias rall='repo_all.sh'
  alias rsyncrepo='repo_sync.sh'
  alias rbackup='repo_backup.sh'
  ```

- Ran sync in `devnotes`:
  ```text
  📦 Repo: devnotes
  → git pull
  Already up to date.
  → staging
  → checking for staged changes
  → committing: auto: sync 2025-10-18 17:40:52
  [main 86a0bd7] auto: sync 2025-10-18 17:40:52
   6 files changed, 10 insertions(+), 124 deletions(-)
   delete mode 100644 automation_suite/README.txt
   delete mode 100755 automation_suite/backup.sh
   delete mode 100755 automation_suite/update.sh
   create mode 100644 backups/.._2025-10-18_17-19-55.tar.gz
  → push
  To https://github.com/Brockmerkwan/dev-notes.git
     6bdcff0..86a0bd7  main -> main
  ✅ Done.
  ```

- Ran backup in `devnotes`:
  ```text
  📦 Repo: devnotes
  → Creating archive at: /Users/brockmerkwan/DevBackups/devnotes/devnotes_2025-10-18_17-42-52.tar.gz
  ✅ Central backup complete.
  Done.
  ```

## Artifacts Created
- GitHub remote updated: `origin/main` now includes automation changes.
- Backup archive(s): `~/DevBackups/devnotes/devnotes_2025-10-18_17-42-52.tar.gz` (and earlier timestamp).

## Next Steps
1. (Optional) Run `repo_all.sh` to sweep `~/Desktop` and `~/Projects` for any other repos and auto-sync/backup them.
2. Proceed to **Lesson 2 — System Health & Audit** (create `sys_audit.sh` to collect macOS system + security baselines and commit outputs into `daily_logs/`).

---
Prepared by ChatGPT — Training Director
