SCHEDULER — Quick Setup

Files in this bundle:
- daily_rotate.sh           -> non-interactive runner that archives your troubleshooting + daily logs
- com.brock.logsentinel.daily.plist -> launchd job to run daily at 18:00 (6 PM) local time
- (Optional) You can switch the runner to use /usr/local/bin/logsentinel later

Install (copy/paste each block):

1) Put files in place:
   mkdir -p ~/Downloads
   cp "/mnt/data/scheduler_bundle/daily_rotate.sh" ~/Downloads/daily_rotate.sh
   chmod +x ~/Downloads/daily_rotate.sh
   cp "/mnt/data/scheduler_bundle/com.brock.logsentinel.daily.plist"  ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist

2) Load the launchd job:
   launchctl unload ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist 2>/dev/null || true
   launchctl load   ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist
   # (It will also run once immediately because RunAtLoad is true)

3) Verify and test:
   launchctl list | grep com.brock.logsentinel.daily || echo "Not listed yet"
   tail -n 50 ~/Projects/devnotes/backups/daily_rotate.log
   tail -n 50 ~/Projects/devnotes/backups/launchd_stdout.log
   tail -n 50 ~/Projects/devnotes/backups/launchd_stderr.log

Change the time:
- Edit Hour/Minute inside: ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist
- Then: launchctl unload ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist
         launchctl load   ~/Library/LaunchAgents/com.brock.logsentinel.daily.plist

Cron alternative (not recommended on modern macOS):
- crontab -e
- Add line (runs at 18:00 daily):
  0 18 * * * /bin/zsh ~/Downloads/daily_rotate.sh
