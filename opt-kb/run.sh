#!/usr/bin/env bash
# run.sh — Orchestrator. guard -> prep -> (claude, nur bei neuen Rohdaten) -> POST (immer, idempotent).
# LLM = eine Stufe; alles drumherum deterministisch. Abo-Billing (kein API-Key).
set -euo pipefail; shopt -s nullglob
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
unset ANTHROPIC_API_KEY                      # Schutz: garantiert Abo-Billing
KB="${KB_HOME:-/opt/kb}"; VAULT="${VAULT:-/opt/kb/vault}"; DRY="${DRY_RUN:-0}"
mkdir -p "$KB/.cache"

notify(){ curl -sf -H "Authorization: Bearer ${NTFY_TOKEN:-}" -d "$1" \
  "${NTFY_URL:-http://localhost:8080}/${NTFY_TOPIC:-kb}" >/dev/null 2>&1 || true; }
real_files(){ find "$1" -type f ! -name '.gitkeep' 2>/dev/null; }
trap 'notify "kb-run ERR (run.log prüfen)"' ERR

exec 9>/tmp/kb.lock; flock -n 9 || { echo "$(date -Is) lock busy, skip"; exit 0; }
cd "$VAULT"

/opt/kb/guard.sh || { echo "$(date -Is) guard: blockiert"; exit 0; }
/opt/kb/scaffold-daily.sh || true
/opt/kb/prep-raw.sh || true

HAVE_RAW=0; [ -n "$(real_files "$VAULT/raw")" ] && HAVE_RAW=1
CHANGED=0; /opt/kb/tasks-changed.sh && CHANGED=1 || true
if [ "$HAVE_RAW" -eq 0 ] && [ "$CHANGED" -eq 0 ]; then
  echo "$(date -Is) empty-gate: nichts zu tun (0 Token)"; exit 0
fi

# ---- LLM-Stufe: NUR wenn neue Rohdaten. tasks-only -> kein LLM, nur deterministisches POST ----
LLM_RC=0
if [ "$HAVE_RAW" -eq 1 ]; then
  if [ "$DRY" = 1 ]; then
    echo "$(date -Is) [DRY_RUN] würde claude -p (${KB_MODEL:-haiku}) ausführen"
  else
    set +e
    claude -p "$(cat task-prompts/daily.md)" \
      --model "${KB_MODEL:-haiku}" --max-turns "${KB_MAX_TURNS:-30}" \
      --output-format json --permission-mode acceptEdits \
      --add-dir wiki --add-dir raw --add-dir tmp \
      --append-system-prompt "Terse. Verarbeitete Quelle selbst von raw/ nach tmp/ verschieben (= erledigt-Marker)." \
      > "$KB/.last_out" 2>>"$KB/run.log"
    LLM_RC=$?
    set -e
    date +%s > "$KB/.last_run"
    echo "$(date -Is)" >> "$KB/.runs-$(date +%F)"
    /opt/kb/cost-watch.sh "$KB/.last_out" || true
    [ "$LLM_RC" -ne 0 ] && notify "kb-run: claude rc=$LLM_RC (run.log) — POST läuft trotzdem"
  fi
fi

# ---- POST (deterministisch, immer, idempotent — auch nach Teil-/Fehl-Run) ----
if [ "$DRY" = 1 ]; then
  /opt/kb/index-assist.sh || true
  /opt/kb/plan.sh || true
  python3 /opt/kb/gen_ics.py || true
  echo "$(date -Is) [DRY_RUN] POST ohne CalDAV/git/ntfy fertig"
  exit 0
fi

/opt/kb/move-processed.sh || true
/opt/kb/archive-stale.sh  || true
/opt/kb/archive-tasks.sh  || true
/opt/kb/tidy-tasks.sh     || true
/opt/kb/index-assist.sh   || true
/opt/kb/plan.sh           || true
python3 /opt/kb/gen_ics.py || true
/opt/kb/sync-caldav.sh    || true

if ! cmp -s out/plan.md "$KB/.cache/plan.md" 2>/dev/null; then
  notify "Tagesplan aktualisiert"
  cp -f out/plan.md "$KB/.cache/plan.md" 2>/dev/null || true
fi

sha256sum tasks.md 2>/dev/null | cut -d' ' -f1 > "$KB/.tasks-hash" || true
git add -A && git commit -q -m "routine $(date -Is)" 2>/dev/null || true
echo "$(date -Is) run fertig (LLM_RC=$LLM_RC)"
