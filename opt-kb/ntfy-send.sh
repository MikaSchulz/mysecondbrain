#!/usr/bin/env bash
# ntfy-send.sh "<text>" — sendet ntfy-Push. Auth: Bearer-Token ODER Basic-Auth (NTFY_USER/PW) ODER offen.
# LXC nutzt i.d.R. Token (setup/30 erzeugt ihn), Docker nutzt Basic-Auth (NTFY_USER/PASSWORD).
set -uo pipefail
source /opt/kb/.env 2>/dev/null || true
msg="$*"; [ -z "$msg" ] && exit 0
url="${NTFY_URL:-http://localhost:8080}/${NTFY_TOPIC:-kb}"
if [ -n "${NTFY_TOKEN:-}" ] && [ "${NTFY_TOKEN}" != "tk_change_me" ]; then
  curl -sf -H "Authorization: Bearer $NTFY_TOKEN" -d "$msg" "$url" >/dev/null 2>&1 || true
elif [ -n "${NTFY_USER:-}" ]; then
  curl -sf -u "$NTFY_USER:${NTFY_PASSWORD:-}" -d "$msg" "$url" >/dev/null 2>&1 || true
else
  curl -sf -d "$msg" "$url" >/dev/null 2>&1 || true
fi
