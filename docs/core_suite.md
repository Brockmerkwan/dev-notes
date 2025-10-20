# Brock Core OS — Core Suite
- **core.sh**: main menu (health, sync, prompt, watcher, dashboards)
- **core_dash.sh**: CLI dashboard
- **core_dash_web.py** + **core_web.sh**: Web dashboard at `http://localhost:7780`
LaunchAgents: `com.brock.dashboard.http` (web), `com.brock.aiwatcher` (watcher), `com.brock.logrotate` (logs)
