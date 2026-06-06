#!/usr/bin/env bash
# plan.sh — tasks.md -> out/plan.md (deterministisch gruppiert, KEIN LLM).
set -euo pipefail
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os, re, sys, datetime
vault = sys.argv[1]
tasks = os.path.join(vault, "tasks.md")
out   = os.path.join(vault, "out", "plan.md")
os.makedirs(os.path.dirname(out), exist_ok=True)
today = datetime.date.today()
TAG = re.compile(r'@(\w+)\(([^)]*)\)')
DUE = re.compile(r'^(\d{4})-(\d{2})-(\d{2})')

buckets = {"overdue":[], "today":[], "week":[], "later":[], "nodate":[]}
if os.path.exists(tasks):
    for line in open(tasks, encoding="utf-8"):
        s=line.strip()
        if not s.startswith("- [ ]"): continue          # nur offene
        tags=dict(TAG.findall(s))
        body=TAG.sub("", s[5:])
        title=re.sub(r'(?:^|\s)#[\w/-]+',"",body).strip(" -\t").strip() or "(ohne Titel)"
        due=tags.get("due","").strip()
        m=DUE.match(due)
        if not m:
            buckets["nodate"].append((None,title,due)); continue
        d=datetime.date(int(m.group(1)),int(m.group(2)),int(m.group(3)))
        t=due[11:16] if len(due)>=16 else ""
        label=f"{title}" + (f" — {t}" if t else "")
        if d<today: buckets["overdue"].append((d,label,due))
        elif d==today: buckets["today"].append((d,label,due))
        elif d<=today+datetime.timedelta(days=7): buckets["week"].append((d,label,due))
        else: buckets["later"].append((d,label,due))

def sec(title, items, withdate=False):
    if not items: return []
    items=sorted(items, key=lambda x:(x[0] or datetime.date.max, x[1]))
    L=[f"## {title}",""]
    for d,label,due in items:
        pref=f"`{d.isoformat()}` " if (withdate and d) else ""
        L.append(f"- {pref}{label}")
    L.append("")
    return L

lines=[f"# Tagesplan — {today.isoformat()}",""]
lines+=sec("⚠️ Überfällig", buckets["overdue"], True)
lines+=sec("Heute", buckets["today"])
lines+=sec("Diese Woche", buckets["week"], True)
lines+=sec("Später", buckets["later"], True)
lines+=sec("Ohne Datum", buckets["nodate"])
if all(not b for b in buckets.values()):
    lines+=["_Keine offenen Tasks._",""]

content="\n".join(lines).rstrip()+"\n"
old=open(out,encoding="utf-8").read() if os.path.exists(out) else None
if old!=content:
    open(out,"w",encoding="utf-8").write(content)
print(f"plan: {sum(len(b) for b in buckets.values())} offene Tasks")
PY
