#!/usr/bin/env bash
set -euo pipefail
IMG="ghcr.io/brockmerkwan/aiwatcher-live:latest"

echo "[local] pulling image…"
docker pull "$IMG" >/dev/null || true

echo "[local] running (no AI)…"
docker run --rm \
  -e RSS_NOAI=1 \
  -e RSS_CONF=/app/rss.yaml \
  "$IMG"
