# AI Watcher — NTFY-Throttled Monitor (Brock Core OS)

Monitors URLs or local files for pattern matches defined in `~/.config/aiwatcher/rules.txt`.  
Notifications are sent via **ntfy.sh** only when hits occur (or when `NTFY_ON_EMPTY=true`).

## CLI Flags
| Flag | Description |
|------|--------------|
| `--init` | Build scaffold (config, sources, rules) |
| `--once` | Run single scan |
| `--daemon` | Loop every 5 min (LaunchAgent compatible) |
| `--mute` | Disable notifications for this run |
| `--quiet` | Suppress “0 picks” (default) |
| `--verbose` | Allow “0 picks” notices |
| `--interval MINS` | Override throttle interval |
| `--set topic=NAME` | Change ntfy topic |
| `--show` | Print config summary |

Logs: `~/.local/state/aiwatcher/aiwatcher.log`  
Config: `~/.config/aiwatcher/config.env`
