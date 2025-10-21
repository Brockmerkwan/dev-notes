#!/usr/bin/env bash
set -euo pipefail
LOGDIR="${HOME}/Projects/devnotes/daily_logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/cloudsync_$(date +%F_%H-%M-%S).log"
REPO="$HOME/Projects/devnotes"
cd "$REPO"

echo "== Phase 2.5 Cloud Sync Start ==" | tee -a "$LOGFILE"

# 1 – Ensure update_readme.sh exists and runs
if [[ ! -x tools/update_readme.sh ]]; then
  cat > tools/update_readme.sh <<'INNEREOF'
#!/usr/bin/env bash
set -euo pipefail
echo "🧠 Updating README..."
STAMP=$(date '+%Y-%m-%d %H:%M:%S')
sed -i "" -e "s/^_Last updated:.*/_Last updated: ${STAMP}/" README.md 2>/dev/null || true
git add README.md
git commit -m "auto(readme): update timestamp ${STAMP}" || true
INNEREOF
  chmod +x tools/update_readme.sh
  echo "🧩 Rebuilt tools/update_readme.sh" | tee -a "$LOGFILE"
fi

bash tools/update_readme.sh | tee -a "$LOGFILE"

# 2 – Check GitHub Actions workflow status via gh API
echo "🔍 Checking GitHub Actions..." | tee -a "$LOGFILE"
if gh run list -R Brockmerkwan/dev-notes --limit 1 &>>"$LOGFILE"; then
  gh run list -R Brockmerkwan/dev-notes --limit 1 >>"$LOGFILE"
else
  echo "⚠️ gh run list unavailable (ensure GitHub CLI v2.50+)" | tee -a "$LOGFILE"
fi

# 3 – Commit and tag verification results
git add "$LOGDIR" || true
STAMP=$(date +%F_%H-%M-%S)
git commit -m "meta(verify): Phase 2.5 Cloud Sync ${STAMP}" || true
git tag -a "meta-verify-cloudsync-${STAMP}" -m "Phase 2.5 Cloud Sync Verification"
git push --follow-tags
echo "✅ Cloud Sync verification complete" | tee -a "$LOGFILE"
