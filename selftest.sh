#!/usr/bin/env bash
# selftest.sh — verifiziert die DETERMINISTISCHE Pipeline in einer Sandbox (kein claude/Netz nötig).
# Testet: gen_ics, plan, index-assist, rollover, tidy-tasks gegen vault-seed + Sample-Daten.
set -euo pipefail
BOOT="$(cd "$(dirname "$0")" && pwd)"
export KB_HOME="$(mktemp -d)"; export VAULT="$KB_HOME/vault"; export TZ=Europe/Berlin
trap 'rm -rf "$KB_HOME"' EXIT
cp -a "$BOOT/vault-seed" "$VAULT"

cat > "$VAULT/wiki/projekt-nuc.md" <<'EOF'
---
title: NUC Second Brain
tags: infra, projekt
sources: processed/notes/idee.md
created: 2026-06-01
updated: 2026-06-06
---
Aufbau des [[Radicale]]-Kalenders.
EOF

FUT=$(date -d "+3 days" +%F); PAST=$(date -d "-2 days" +%F)
cat > "$VAULT/tasks.md" <<EOF
# Tasks
## Offen
- [ ] Zahnarzt @uid(aaa111) @due($FUT 14:00) @alarm(15m) #gesundheit
- [ ] Altes Meeting @uid(bbb222) @due($PAST 09:00) #arbeit
- [x] Erledigt @uid(ccc333) @due($PAST) #done
- [ ] Todo ohne Zeit @uid(ddd444) @due($PAST)
- [ ] Backlog @uid(eee555) #idee
EOF

fail(){ echo "FAIL: $1"; exit 1; }
"$BOOT/opt-kb/index-assist.sh" >/dev/null
python3 "$BOOT/opt-kb/gen_ics.py" >/dev/null
"$BOOT/opt-kb/rollover.sh" >/dev/null
"$BOOT/opt-kb/tidy-tasks.sh" >/dev/null
"$BOOT/opt-kb/plan.sh" >/dev/null

[ -f "$VAULT/out/events/aaa111.ics" ] || fail "aaa111.ics fehlt"
grep -q "TZID:Europe/Berlin" "$VAULT/out/events/aaa111.ics" || fail "VTIMEZONE fehlt"
grep -q "BEGIN:VALARM" "$VAULT/out/events/aaa111.ics" || fail "VALARM fehlt"
grep -q "@uid(bbb222)" "$VAULT"/archive/tasks-*.md || fail "vergangener Termin nicht archiviert"
grep -q "@uid(ccc333)" "$VAULT"/archive/tasks-*.md || fail "erledigter Task nicht archiviert"
grep -q "@uid(bbb222)" "$VAULT/tasks.md" && fail "bbb222 noch in tasks.md"
grep -q "@due($(date +%F))" "$VAULT/tasks.md" || fail "rollover hat ddd444 nicht auf heute geschoben"
grep -q "AUTO:end" "$VAULT/index.md" || fail "index AUTO-Block fehlt"
grep -q "\[\[projekt-nuc\]\]" "$VAULT/index.md" || fail "index listet wiki-Seite nicht"

echo "selftest: OK ✓ (deterministische Pipeline funktioniert)"
