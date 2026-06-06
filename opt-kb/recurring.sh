#!/usr/bin/env bash
# recurring.sh — Phase 3 (STUB): wiederkehrende Events (Geburtstage/Reviews/Rechnungen) +
# OAuth-Token-Renewal-Reminder in tasks.md sicherstellen. cron (täglich).
#
# Geplant: liest /opt/kb/vault/recurring.md (Format wie tasks.md, je Zeile @rrule), und stellt sicher,
# dass die nächste Instanz als @uid/@due in tasks.md steht (idempotent über @uid).
# Token-Renewal: ~11 Monate nach setup-token einen Reminder anlegen.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"; KB="${KB_HOME:-/opt/kb}"

# --- OAuth-Token-Renewal-Reminder (einmalig anlegen) ---
TASKS="$VAULT/tasks.md"
if [ -f "$KB/.token-installed" ] && ! grep -q '@uid(tokenrenew)' "$TASKS" 2>/dev/null; then
  due=$(date -d "$(cat "$KB/.token-installed") +330 days" +%F 2>/dev/null || true)
  [ -n "$due" ] && printf -- '- [ ] Claude OAuth-Token erneuern (claude setup-token) @uid(tokenrenew) @due(%s) @alarm(1d) #wartung\n' "$due" >> "$TASKS"
fi

echo "recurring: stub (Phase 3) — Token-Reminder geprüft"
