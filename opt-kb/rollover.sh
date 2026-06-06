#!/usr/bin/env bash
# rollover.sh — offene date-only Tasks mit vergangenem @due auf heute schieben (KEIN LLM).
# Termine MIT Uhrzeit bleiben unverändert (die archiviert tidy-tasks). cron (z.B. täglich früh).
set -euo pipefail
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os,re,sys,datetime
vault=sys.argv[1]; tasks=os.path.join(vault,"tasks.md")
if not os.path.exists(tasks): sys.exit(0)
today=datetime.date.today()
OPEN=re.compile(r'^\s*- \[ \]')
DUE =re.compile(r'@due\((\d{4})-(\d{2})-(\d{2})(?![ T]\d)\)')   # date-only (keine Uhrzeit danach)
out=[]; n=0
for line in open(tasks,encoding="utf-8"):
    if OPEN.match(line):
        m=DUE.search(line)
        if m:
            d=datetime.date(int(m.group(1)),int(m.group(2)),int(m.group(3)))
            if d<today:
                line=DUE.sub(f"@due({today.isoformat()})", line); n+=1
    out.append(line)
if n:
    open(tasks,"w",encoding="utf-8").writelines(out)
print(f"rollover: {n} Tasks auf heute geschoben")
PY
