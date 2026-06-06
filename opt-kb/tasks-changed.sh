#!/usr/bin/env bash
# tasks-changed.sh — return 0 wenn tasks.md sich seit letztem verarbeiteten Stand geändert hat
# (User-Edit via Obsidian, recurring.sh, rollover ...). Steuert Empty-Gate + ob POST/gen_ics nötig ist.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"; VAULT="${VAULT:-/opt/kb/vault}"
f="$VAULT/tasks.md"
[ -f "$f" ] || exit 1
cur=$(sha256sum "$f" | cut -d' ' -f1)
prev=$(cat "$KB/.tasks-hash" 2>/dev/null || echo "")
[ "$cur" != "$prev" ] && exit 0
exit 1
