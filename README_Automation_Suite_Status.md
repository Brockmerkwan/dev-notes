# ⚙️ System Status – Automation Suite v1

**Purpose:**  
Automated nightly system audits and summary commits.

| Agent | Description | Schedule | Status | Logs |
|-------|--------------|-----------|--------|------|
| `com.brock.sysaudit` | Runs the defensive system audit, produces summary + baseline diff | 02:00 AM daily | ✅ | `/tmp/com.brock.sysaudit.out /err` |
| `com.brock.sysaudit.commit` | Copies summaries to repo and commits/pushes | 02:10 AM daily | ✅ | `/tmp/com.brock.sysaudit.commit.out /err` |

---

### 📁 File Locations

| Type | Path |
|------|------|
| Audit output | `~/SysAudits/` |
| Summaries | `~/SysAudits/summaries/` |
| Baselines | `~/SysAudits/baselines/` |
| Repo commits | `~/Projects/devnotes/daily_logs/` |

---

### 🧠 Managing the Agents

```bash
# Enable / disable agents
launchctl load   ~/Library/LaunchAgents/com.brock.sysaudit.plist
launchctl unload ~/Library/LaunchAgents/com.brock.sysaudit.plist

launchctl load   ~/Library/LaunchAgents/com.brock.sysaudit.commit.plist
launchctl unload ~/Library/LaunchAgents/com.brock.sysaudit.commit.plist

# Manual runs
launchctl kickstart gui/$UID/com.brock.sysaudit
launchctl kickstart gui/$UID/com.brock.sysaudit.commit
```

---

### 🧰 Troubleshooting

- Ignore harmless `getcwd: Operation not permitted` messages (macOS TCC quirk).
- Verify summaries appear in `~/SysAudits/summaries/`.
- Review `/tmp/...err` for real errors if they occur.
- Both agents should show status code `0` under `launchctl list | grep sysaudit`.

---

**Status:** 🟢 Stable – verified operational  
**Maintainer:** Brock Merkwan  
**Last verification:** 2025‑10‑18

> “Automate, commit, move on. Gen X rules of sys‑ops.” 🤘
