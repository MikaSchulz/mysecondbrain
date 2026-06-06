#!/usr/bin/env bash
# watch-raw.sh — systemd-Service. inotify auf raw/urgent/ -> sofort run.sh (near-realtime-Bypass).
# Normale Inputs laufen über den cron-Tick + 30-min-Sammelfenster (guard).
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
URG="$VAULT/raw/urgent"; mkdir -p "$URG"
echo "watch-raw: beobachte $URG"
while inotifywait -e close_write,moved_to,create "$URG" >/dev/null 2>&1; do
  sleep 5    # kurze Sammelpause für Bursts
  /opt/kb/run.sh >> /opt/kb/run.log 2>&1 || true
done
