#!/usr/bin/env bash
# index-assist.sh — regeneriert den AUTO-Block in index.md aus wiki/-Frontmatter (KEIN LLM).
# Nur zwischen <!-- AUTO:start --> und <!-- AUTO:end -->. archive/ etc. werden ignoriert.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
exec python3 - "$VAULT" <<'PY'
import os, re, sys
vault=sys.argv[1]
wiki=os.path.join(vault,"wiki")
index=os.path.join(vault,"index.md")
START="<!-- AUTO:start -->"; END="<!-- AUTO:end -->"

def frontmatter(path):
    try: txt=open(path,encoding="utf-8").read()
    except Exception: return {}
    if not txt.startswith("---"): return {}
    end=txt.find("\n---",3)
    if end<0: return {}
    fm={}
    for line in txt[3:end].splitlines():
        m=re.match(r'\s*([\w-]+)\s*:\s*(.*)$', line)
        if m: fm[m.group(1).lower()]=m.group(2).strip().strip('"')
    return fm

pages=[]
for root,_,files in os.walk(wiki):
    for fn in sorted(files):
        if not fn.endswith(".md"): continue
        p=os.path.join(root,fn)
        rel=os.path.relpath(p, vault)
        fm=frontmatter(p)
        title=fm.get("title") or os.path.splitext(fn)[0]
        tags=[t.strip().strip('[]') for t in re.split(r'[,\s]+', fm.get("tags","")) if t.strip().strip('[]')]
        updated=fm.get("updated") or fm.get("created") or ""
        pages.append((title, rel, tags, updated))

# nach Tag gruppieren
by_tag={}
for title,rel,tags,upd in pages:
    for t in (tags or ["(ohne Tag)"]):
        by_tag.setdefault(t,[]).append((title,rel,upd))

lines=[START, f"<!-- regeneriert: {len(pages)} Seiten. Nicht von Hand editieren. -->",""]
lines.append(f"**{len(pages)} Wiki-Seiten**")
lines.append("")
for tag in sorted(by_tag):
    lines.append(f"### {tag}")
    for title,rel,upd in sorted(by_tag[tag], key=lambda x:x[0].lower()):
        # Obsidian-Wikilink auf Dateinamen ohne .md
        name=os.path.splitext(os.path.basename(rel))[0]
        suf=f"  _(akt. {upd})_" if upd else ""
        lines.append(f"- [[{name}]]{suf}")
    lines.append("")
lines.append(END)
block="\n".join(lines)

if os.path.exists(index):
    txt=open(index,encoding="utf-8").read()
else:
    txt=f"# Index\n\n{START}\n{END}\n"
if START in txt and END in txt:
    txt=re.sub(re.escape(START)+r".*?"+re.escape(END), block, txt, flags=re.S)
else:
    txt=txt.rstrip()+"\n\n"+block+"\n"
old=open(index,encoding="utf-8").read() if os.path.exists(index) else None
if old!=txt:
    open(index,"w",encoding="utf-8").write(txt)
print(f"index-assist: {len(pages)} Seiten, {len(by_tag)} Tags")
PY
