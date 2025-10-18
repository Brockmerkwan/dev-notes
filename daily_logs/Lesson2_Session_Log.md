# Lesson 2 — System Health & Audit (Defensive)
**Date:** 2025-10-18
**User:** Brock Merkwan

## Summary
- Created and installed a portable defensive audit script: `sys_audit_defensive.sh`.
- Script writes read-only system snapshots to `~/SysAudits/` by default.
- Added a VS Code task for one-click audits.
- Ran the repo-bound `sys_audit.sh` earlier; defensive version provides a portable alternative for any machine you control.

## Artifacts
- `sys_audit_defensive.sh` — portable defensive audit (read-only)
- VS Code Task: `.vscode/tasks.json` snippet for easy execution
- Output samples: `~/SysAudits/<hostname>_YYYY-MM-DD_HH-MM-SS.txt`

## Next
- Commit defensive script to `~/scripts` or your `devnotes` repo under `scripts/` for central access.
- Proceed to build the Red-Team Study Checklist & Defensive Mapping.
