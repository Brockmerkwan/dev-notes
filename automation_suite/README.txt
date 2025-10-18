# Automation Suite (Level 2 — Module 1)

This starter pack contains two scripts:

- `update.sh` — Pulls from remote, stages changes, creates a commit *only if there are staged changes*, pushes, and logs to `daily_logs/YYYY-MM-DD_update.log`.
- `backup.sh` — Creates a timestamped `.tar.gz` archive of your repo (excluding `.git`) in `backups/`, and keeps only the last 10 archives.

## How to Install (macOS, zsh)
1) Move the folder `automation_suite` into your Git repo (recommended path: `your-repo/scripts/`).
2) Make scripts executable:
   ```bash
   chmod +x automation_suite/update.sh automation_suite/backup.sh
   ```
3) Run from anywhere:
   ```bash
   ./automation_suite/update.sh
   ./automation_suite/backup.sh
   ```
   (If you placed the folder at `your-repo/scripts/`, the scripts auto-detect the repo root.)

## Notes
- The update script avoids empty commits using `git diff --cached --quiet`.
- Logs are saved to `daily_logs/` at the repo root.
- Backups are created in `backups/` at the repo root and pruned to the 10 most recent.

## Tip
Add an alias to your shell for shorter commands:
```bash
alias uprepo='./automation_suite/update.sh'
alias backrepo='./automation_suite/backup.sh'
```
