# 🧰 Brock's DevTools Suite  
_A lightweight automation toolkit for syncing, backing up, and maintaining Git repositories._

---

## 🚀 Overview
This suite provides a set of simple, reliable shell scripts for everyday DevOps and system maintenance.  
Designed for **macOS or Linux**, the scripts make it easy to:
- ✅ Sync any Git repo automatically (pull → add → commit-if-changed → push)
- 🗄️ Back up repos to a central or external location
- 🌐 Batch process all repos on your system (Desktop, Projects, etc.)

---

## 📂 Scripts Included

| Script | Purpose |
|:--|:--|
| **`repo_sync.sh`** | Pulls latest, stages all changes, commits only if changes exist, and pushes. |
| **`repo_backup.sh`** | Creates a compressed `.tar.gz` backup of the current repo (excluding `.git`) to `~/DevBackups/<repo>` and keeps only the 10 most recent. |
| **`repo_all.sh`** | Scans multiple folders (like `~/Desktop`, `~/Projects`) and runs both `repo_sync` + `repo_backup` for each detected repo. |

---

## 🧩 Setup

### 1. Installation
```bash
mkdir -p ~/scripts
cp repo_sync.sh repo_backup.sh repo_all.sh ~/scripts/
chmod +x ~/scripts/repo_*.sh
echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Optional Aliases
For faster access:
```bash
alias rsyncme='repo_sync.sh'
alias rbackup='repo_backup.sh'
alias rall='repo_all.sh'
```

---

## 🧪 Usage

### Inside a single repo
```bash
cd ~/Desktop/devnotes
repo_sync.sh
repo_backup.sh
```

**Result:**
- Logs committed automatically with timestamp.
- Backup stored at `~/DevBackups/devnotes/devnotes_YYYY-MM-DD_HH-MM-SS.tar.gz`

### Across all repos
```bash
repo_all.sh
```

**Default scan locations:**  
`~/Desktop`, `~/Projects`  
You can edit the paths at the top of `repo_all.sh` to include others.

---

## 💾 Backup Configuration

You can customize your backup paths:
```bash
export CENTRAL_BACKUP_DIR="$HOME/DevBackups"
export EXTERNAL_BACKUP_DIR="/Volumes/EXT_DRIVE/DevBackups"
```
Run `repo_backup.sh` again — it will automatically mirror to your external drive if available.

---

## 🛠️ System Requirements
- macOS or Linux
- Git installed and configured
- Zsh or Bash shell

---

## 🎯 Lesson Progress
| Lesson | Description | Status |
|:--|:--|:--|
| **Lesson 1** | Applied Automation — Git & Backup Suite | ✅ Complete |
| **Lesson 2** | System Health & Audit (sys_audit.sh) | ⏳ In Progress |
| **Lesson 3** | Docker + Remote Ops Automation | 🔒 Locked |

---

## 📜 License
MIT — free to use, modify, and distribute.

---

## 👤 Author
**Brock Merkwan**  
Automation Engineer • Writer • Builder of creative tools  
🔗 [GitHub Profile](https://github.com/Brockmerkwan)
