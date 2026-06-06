#!/usr/bin/env bash
# health.sh — prüft Radicale/ntfy (+ optional OpenWA) erreichbar; Restart-Versuch + ntfy-Alert. cron alle 15 min.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
notify(){ curl -sf -H "Authorization: Bearer ${NTFY_TOKEN:-}" -d "$1" "${NTFY_URL:-http://localhost:8080}/${NTFY_TOPIC:-kb}" >/dev/null 2>&1 || true; }

check(){ # name url systemd-unit
  local name="$1" url="$2" unit="$3"
  if curl -sf -m 5 -o /dev/null "$url" 2>/dev/null; then return 0; fi
  echo "health: $name DOWN ($url)"
  if [ -n "$unit" ] && command -v systemctl >/dev/null; then systemctl restart "$unit" >/dev/null 2>&1 || true; sleep 3; fi
  if curl -sf -m 5 -o /dev/null "$url" 2>/dev/null; then notify "kb-health: $name war down, neugestartet ✓"; else notify "kb-health: $name DOWN ❌ (Restart fehlgeschlagen)"; fi
}

check "Radicale" "${RADICALE_URL:-http://localhost:5232}/" "${RADICALE_UNIT:-radicale}"
check "ntfy"     "${NTFY_URL:-http://localhost:8080}/v1/health" "${NTFY_UNIT:-ntfy}"
# OpenWA optional (Phase 3): check "OpenWA" "http://localhost:8002/..." "openwa"
echo "health: ok"
