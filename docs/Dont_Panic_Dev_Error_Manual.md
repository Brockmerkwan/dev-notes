# Brock’s Don't Panic – Dev Error Survival Manual

**Date:** 2025-10-19

_Working Directory of “oh shit” moments → triage, quick fixes, and when to move on_


## Philosophy (90s Kid NetOps Mode)

- If the command completed and produced the output you needed → move on.
- Warnings aren’t failures. Red text ≠ broken system.
- Ship the summary, not the noise. Investigate only what blocks the next step.
- Automate receipts: logs + summaries prove success even when the shell whines.

## Rapid Triage — 3 Questions

- 1) Did the run finish? ✅ Ignore if yes.
- 2) Did I get the artifact (file/commit/output)? ✅ Ignore if yes.
- 3) Will this block the next command? ❌ Only then fix it.

## macOS / Launchd / Terminal

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `getcwd: Operation not permitted` | launchd/TCC starting in a protected dir | **OK to ignore** | Harmless; use WorkingDirectory or cd $HOME to silence |
| `shell-init: error retrieving current directory` | Same as above (TCC sandbox) | **OK to ignore** | Job still runs; add cd "$HOME" at script start |
| `launchctl list shows -15` | Prior instance terminated (kickstart -k) | **OK to ignore** | It’s a signal, not a failure |
| `launchctl print shows no PID` | Agent idle (not currently running) | **OK to ignore** | It’s loaded; will run at schedule |

## Git

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `nothing to commit, working tree clean` | No staged changes | **OK to ignore** | You’re up to date |
| `Your branch is up to date with 'origin/main'` | Remote and local match | **OK to ignore** | Perfect state |
| `Untracked files present` | New files not added yet | **Investigate** | Use git add if you want them tracked |
| `warning: LF will be replaced by CRLF` | Line endings normalization | **OK to ignore** | Cosmetic; configure .gitattributes if desired |
| `fatal: not a git repository` | You’re outside a repo | **OK to ignore** | Just cd into the repo and retry |

## Bash / Zsh / Shell

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `command not found` | Tool isn’t in PATH or not installed | **Investigate** | Install or add to PATH; for launchd also set PATH in plist |
| `No such file or directory (on /tmp/... logs)` | Log hasn’t been written yet | **OK to ignore** | Appears after first scheduled run |
| `Permission denied (find, ls)` | Protected directories | **OK to ignore** | Append 2>/dev/null; doesn’t affect rest |

## Python

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `ModuleNotFoundError` | Package missing in environment | **Investigate** | pip install <pkg> or use venv; verify interpreter |
| `IndentationError / SyntaxError` | Typos/formatting | **Investigate** | Fix file; linters help |
| `pip warning: script installed in ... not on PATH` | Binary dir not on PATH | **OK to ignore** | Add path to shell rc for convenience |

## JavaScript / Node

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `npm WARN` | Non-fatal advisory | **OK to ignore** | Unless install breaks, proceed |
| `node: command not found` | Node not installed or PATH issue | **Investigate** | Install via nvm; reload shell |
| `ESLint warnings` | Style issues | **OK to ignore** | Fix later unless CI blocks |

## Docker

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `Cannot connect to the Docker daemon` | Daemon not running | **Investigate** | Launch Docker Desktop / start service |
| `WARNING: No swap limit support` | Kernel cgroup limitation warning | **OK to ignore** | Usually harmless for dev |

## Homebrew / apt / pkg managers

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `brew doctor warnings` | Environment advisory | **OK to ignore** | Only fix if installs fail |
| `apt-get: command not found (on macOS)` | Wrong manager for OS | **OK to ignore** | Use brew on macOS |
| `dpkg/journalctl: command not found (on macOS)` | Linux-only tools | **OK to ignore** | Use netstat/Console on mac |

## Networking

| Error | What it means | OK to Ignore? | Quick fix / Note |
|---|---|---|---|
| `ss: command not found (macOS)` | Linux-only | **OK to ignore** | Use netstat -anv on macOS |
| `Operation not permitted (port scan)` | Privileged action blocked | **Investigate** | Use sudo or change method; ensure you have permission |

---

**Rule of thumb:** If the run finished **and** produced the artifact you needed, keep moving. Save deep dives for blockers.
