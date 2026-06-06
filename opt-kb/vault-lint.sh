#!/usr/bin/env bash
# vault-lint.sh — tote [[wikilinks]] + Seiten ohne Frontmatter finden -> Report (+ ntfy bei Funden). cron.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os,re,sys
vault=sys.argv[1]; wiki=os.path.join(vault,"wiki")
names=set(); pages=[]
for r,_,fs in os.walk(wiki):
    for fn in fs:
        if fn.endswith(".md"):
            names.add(os.path.splitext(fn)[0]); pages.append(os.path.join(r,fn))
dead=[]; nofm=[]
LINK=re.compile(r'\[\[([^\]|#]+)')
for p in pages:
    txt=open(p,encoding="utf-8").read()
    if not txt.startswith("---"): nofm.append(os.path.relpath(p,vault))
    for m in LINK.findall(txt):
        if m.strip() not in names: dead.append(f"{os.path.relpath(p,vault)} -> [[{m.strip()}]]")
print(f"vault-lint: {len(pages)} Seiten, {len(dead)} tote Links, {len(nofm)} ohne Frontmatter")
for d in dead[:50]: print("  DEAD", d)
for n in nofm[:50]: print("  NOFM", n)
if dead or nofm:
    import subprocess
    msg=f"kb-lint: {len(dead)} tote Links, {len(nofm)} ohne Frontmatter"
    tok=os.environ.get("NTFY_TOKEN",""); url=os.environ.get("NTFY_URL","http://localhost:8080"); top=os.environ.get("NTFY_TOPIC","kb")
    subprocess.run(["curl","-sf","-H",f"Authorization: Bearer {tok}","-d",msg,f"{url}/{top}"],capture_output=True)
PY
