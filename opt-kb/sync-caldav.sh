#!/usr/bin/env bash
# sync-caldav.sh — out/events/*.ics -> Radicale.
#   1) Absagen (.cancel-events): CalDAV-DELETE + .ics weg + Zeile aus tasks.md raus.
#   2) PUT nur GEÄNDERTE .ics (cmp gegen Cache).  Archivierte/vergangene Events bleiben unangetastet!
set -euo pipefail; shopt -s nullglob
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"; VAULT="${VAULT:-/opt/kb/vault}"
EVT="$VAULT/out/events"; CACHE="$KB/.cache/caldav"; mkdir -p "$CACHE"
BASE="${RADICALE_URL:-http://localhost:5232}/${RADICALE_USER:-kb}/${RADICALE_CALENDAR:-routine}"
AUTH=(-u "${RADICALE_USER:-kb}:${RADICALE_PW:-}")
CANCEL="$VAULT/.cancel-events"; TASKS="$VAULT/tasks.md"
[ "${DRY_RUN:-0}" = 1 ] && { echo "sync-caldav: DRY_RUN, skip"; exit 0; }

extract_uid(){ # aus einer Zeile die uid ziehen (@uid(xxx) oder bare token)
  if [[ "$1" =~ @uid\(([^\)]+)\) ]]; then echo "${BASH_REMATCH[1]}"; else echo "$1" | tr -d '[:space:]'; fi
}

# --- 1) Absagen ---
if [ -s "$CANCEL" ]; then
  while IFS= read -r line; do
    [ -z "${line// }" ] && continue
    uid=$(extract_uid "$line"); [ -z "$uid" ] && continue
    curl -sf "${AUTH[@]}" -X DELETE "$BASE/$uid.ics" >/dev/null 2>&1 || true
    rm -f "$EVT/$uid.ics" "$CACHE/$uid.ics"
    # Zeile(n) mit dieser uid aus tasks.md entfernen
    [ -f "$TASKS" ] && sed -i "/@uid($uid)/d" "$TASKS" || true
    echo "sync-caldav: abgesagt+gelöscht uid=$uid"
  done < "$CANCEL"
  : > "$CANCEL"
fi

# --- 2) PUT geänderte ---
for f in "$EVT"/*.ics; do
  name=$(basename "$f")
  if ! cmp -s "$f" "$CACHE/$name" 2>/dev/null; then
    if curl -sf "${AUTH[@]}" -H "Content-Type: text/calendar; charset=utf-8" -T "$f" "$BASE/$name" >/dev/null 2>&1; then
      cp -f "$f" "$CACHE/$name"; echo "sync-caldav: PUT $name"
    else
      echo "sync-caldav: PUT FEHLER $name" >&2
    fi
  fi
done
exit 0
