#!/usr/bin/env bash
# backup.sh — nightly off-NUC Snapshot von /opt/kb via restic. cron (z.B. 03:30).
# Voraussetzung in .env: RESTIC_REPOSITORY (off-NUC!), RESTIC_PASSWORD. Sonst nur Warnung.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"
notify(){ curl -sf -H "Authorization: Bearer ${NTFY_TOKEN:-}" -d "$1" "${NTFY_URL:-http://localhost:8080}/${NTFY_TOPIC:-kb}" >/dev/null 2>&1 || true; }
if [ -z "${RESTIC_REPOSITORY:-}" ] || [ -z "${RESTIC_PASSWORD:-}" ]; then
  echo "backup: RESTIC_REPOSITORY/PASSWORD nicht gesetzt — übersprungen"; notify "kb-backup: nicht konfiguriert (off-NUC restic fehlt)"; exit 0
fi
export RESTIC_REPOSITORY RESTIC_PASSWORD
restic snapshots >/dev/null 2>&1 || restic init
if restic backup "$KB" --exclude "$KB/.cache" --tag kb >/dev/null 2>&1; then
  restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune >/dev/null 2>&1 || true
  echo "backup: ok"
else
  echo "backup: FEHLER" >&2; notify "kb-backup FEHLER"
fi
