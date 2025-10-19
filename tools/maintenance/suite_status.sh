#!/bin/zsh
echo "=== Launchd ==="
launchctl list | egrep 'logsentinel.daily|downloads.tidy.weekly|archive.compactor.monthly|maintenance.overview.daily' || echo "(none)"
echo "\n=== Logs ==="
tail -n 6 "$HOME/Projects/devnotes/backups/daily_rotate.log" 2>/dev/null || true
tail -n 6 "$HOME/Downloads/_Archive/_tidy_weekly.log" 2>/dev/null || true
tail -n 6 "$HOME/Downloads/_Archive/_compactor_stdout.log" 2>/dev/null || true
