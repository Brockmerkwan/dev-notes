#!/bin/zsh
# daily_rotate.sh — non-interactive daily rotation for Brock
# Calls the simple log_sentinel.sh (not the visual menu) with preset paths.
# Writes a small log to ~/Projects/devnotes/backups/daily_rotate.log

set -euo pipefail

SIMPLE="${HOME}/Downloads/log_sentinel.sh"   # prefer the simple script you already have
# Fallback: if you later install the PLUS script to PATH as "logsentinel", you can switch to that.
# SIMPLE="/usr/local/bin/logsentinel"

DEVROOT="${HOME}/Projects/devnotes"
OUTDIR="${DEVROOT}/backups"
TROUBLE="${DEVROOT}/docs/troubleshooting"
DAILY="${DEVROOT}/daily_logs"
LOGFILE="${OUTDIR}/daily_rotate.log"

mkdir -p "${OUTDIR}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(ts)] start rotation" >> "${LOGFILE}"

if [[ ! -x "${SIMPLE}" ]]; then
  echo "[$(ts)] ERROR: ${SIMPLE} not found or not executable" >> "${LOGFILE}"
  exit 1
fi

# Rotate troubleshooting markdowns
"${SIMPLE}" rotate --path "${TROUBLE}" --pattern '*.md' --keep 7 --outdir "${OUTDIR}" --prefix devnotes --compress gz >> "${LOGFILE}" 2>&1

# Rotate daily markdowns
"${SIMPLE}" rotate --path "${DAILY}" --pattern '*.md' --keep 7 --outdir "${OUTDIR}" --prefix daily --compress gz >> "${LOGFILE}" 2>&1

echo "[$(ts)] done" >> "${LOGFILE}"
