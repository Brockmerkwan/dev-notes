#!/usr/bin/env bash
cat <<'TXT'
RunPod deploy checklist
-----------------------
Image: ghcr.io/brockmerkwan/aiwatcher-live:latest
Registry: GitHub Container Registry (GHCR)
Credentials:
  - Username: brockmerkwan
  - Password: <GitHub PAT with read:packages>

Env (start simple):
  RSS_NOAI=1
  RSS_CONF=/app/rss.yaml

Later (enable AI scoring):
  unset RSS_NOAI
  OLLAMA_HOST=http://host.docker.internal:11434    # or remote ollama
  # or OLLAMA_MODEL=llama3.1:8b (if container has Ollama running)

What to expect:
  - On boot: one watcher pass, then hourly heartbeat
  - ntfy topic is from rss.yaml (default "brock-live-feed")

Debug:
  - If pulls fail → run scripts/fix_ghcr_login.sh and re-enter PAT
  - If pushes spam → raise min_score in rss.yaml or keep RSS_NOAI=1
TXT
