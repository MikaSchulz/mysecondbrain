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

# Radicale legt Collections NICHT per PUT an -> einmal MKCALENDAR (idempotent; bei Existenz Fehler ignoriert).
ensure_collection(){
  curl -sf "${AUTH[@]}" -X MKCALENDAR -H "Content-Type: application/xml" --data \
'<?xml version="1.0" encoding="utf-8"?>
<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:caldav">
 <D:set><D:prop>
  <D:displayname>'"${RADICALE_CALENDAR:-routine}"'</D:displayname>
  <C:supported-calendar-component-set><C:comp name="VEVENT"/></C:supported-calendar-component-set>
 </D:prop></D:set>
</C:mkcalendar>' "$BASE/" >/dev/null 2>&1 || true
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
pending=0; for f in "$EVT"/*.ics; do cmp -s "$f" "$CACHE/$(basename "$f")" 2>/dev/null || pending=1; done
[ "$pending" = 1 ] && ensure_collection      # nur wenn was zu PUTten ist
for f in "$EVT"/*.ics; do
  name=$(basename "$f")
  if ! cmp -s "$f" "$CACHE/$name" 2>/dev/null; then
    code=$(curl -s -o /dev/null -w '%{http_code}' "${AUTH[@]}" -H "Content-Type: text/calendar; charset=utf-8" -T "$f" "$BASE/$name")
    case "$code" in
      2*) cp -f "$f" "$CACHE/$name"; echo "sync-caldav: PUT $name ($code)";;
      *)  echo "sync-caldav: PUT FEHLER $name (HTTP $code)" >&2;;
    esac
  fi
done
exit 0
