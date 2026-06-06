#!/usr/bin/env bash
# tidy-tasks.sh — deterministisch (KEIN LLM): erledigte [x] + vergangene Termine (mit Uhrzeit)
# aus tasks.md -> archive/tasks-YYYY-MM.md.  KALENDER BLEIBT (kein CalDAV-DELETE — nur Absage löscht).
# Offene date-only Tasks in der Vergangenheit bleiben (rollover.sh schiebt die).
set -euo pipefail
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os, re, sys, datetime
vault=sys.argv[1]
tasks=os.path.join(vault,"tasks.md")
if not os.path.exists(tasks): sys.exit(0)
now=datetime.datetime.now()
arch=os.path.join(vault,"archive",f"tasks-{now:%Y-%m}.md")
TASK=re.compile(r'^\s*- \[( |x|X)\]')
DUE =re.compile(r'@due\((\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?\)')

keep=[]; archived=[]
for line in open(tasks,encoding="utf-8"):
    m=TASK.match(line)
    if not m: keep.append(line); continue
    done = m.group(1).lower()=="x"
    dm=DUE.search(line)
    archive=False
    if done:
        archive=True
    elif dm and dm.group(4) is not None:                 # Termin mit Uhrzeit
        dt=datetime.datetime(int(dm.group(1)),int(dm.group(2)),int(dm.group(3)),int(dm.group(4)),int(dm.group(5)))
        if dt < now: archive=True
    (archived if archive else keep).append(line)

if archived:
    os.makedirs(os.path.dirname(arch),exist_ok=True)
    with open(arch,"a",encoding="utf-8") as a:
        a.write(f"\n<!-- archiviert {now:%Y-%m-%d %H:%M} -->\n")
        a.writelines(archived)
    with open(tasks,"w",encoding="utf-8") as t:
        t.writelines(keep)
print(f"tidy-tasks: {len(archived)} archiviert")
PY
