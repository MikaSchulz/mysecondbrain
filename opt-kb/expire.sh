#!/usr/bin/env bash
# expire.sh — wiki-Seiten mit Frontmatter `expires: YYYY-MM-DD` < heute -> archive/stale/. cron (täglich).
set -euo pipefail
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os,re,sys,datetime,shutil,subprocess
vault=sys.argv[1]; wiki=os.path.join(vault,"wiki"); dst=os.path.join(vault,"archive","stale")
today=datetime.date.today(); EXP=re.compile(r'^expires:\s*(\d{4})-(\d{2})-(\d{2})',re.M)
os.makedirs(dst,exist_ok=True); n=0
for r,_,fs in os.walk(wiki):
    for fn in fs:
        if not fn.endswith(".md"): continue
        p=os.path.join(r,fn); txt=open(p,encoding="utf-8").read()
        if not txt.startswith("---"): continue
        head=txt[:txt.find("\n---",3)+4] if "\n---" in txt[3:] else txt
        m=EXP.search(head)
        if m and datetime.date(int(m.group(1)),int(m.group(2)),int(m.group(3)))<today:
            rel=os.path.relpath(p,vault); out=f"archive/stale/{fn}"
            if os.path.exists(os.path.join(vault,out)): out=f"archive/stale/{int(datetime.datetime.now().timestamp())}-{fn}"
            try: subprocess.run(["git","-C",vault,"mv",rel,out],check=True,capture_output=True)
            except Exception: shutil.move(p,os.path.join(vault,out))
            n+=1; print("expire:",rel,"->",out)
print(f"expire: {n} abgelaufen")
PY
