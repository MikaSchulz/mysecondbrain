#!/usr/bin/env python3
"""gen_ics.py — tasks.md -> out/events/<uid>.ics  (1 VEVENT/Datei, Europe/Berlin, deterministisch).

- Liest aktive Termin-Zeilen aus tasks.md (Zeilen mit @uid und @due).
- Erzeugt pro Event eine stabile .ics (kein Wall-Clock -> idempotent; sync-caldav PUTtet nur bei Diff).
- LÖSCHT NICHTS in out/events/ (archivierte Events bleiben). Absagen macht sync-caldav via .cancel-events.
- Reine stdlib, kein externes Paket.
"""
import os, re, sys, hashlib

VAULT = os.environ.get("VAULT", "/opt/kb/vault")
TASKS = os.path.join(VAULT, "tasks.md")
OUT   = os.path.join(VAULT, "out", "events")

VTIMEZONE = """BEGIN:VTIMEZONE
TZID:Europe/Berlin
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
END:STANDARD
END:VTIMEZONE"""

TAG_RE   = re.compile(r'@(\w+)\(([^)]*)\)')
HASH_RE  = re.compile(r'(?:^|\s)#([\w/-]+)')
DUE_DT   = re.compile(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?$')
ALARM_RE = re.compile(r'^(\d+)\s*([mhd])$')
RRULE_MAP = {"daily":"FREQ=DAILY","weekly":"FREQ=WEEKLY","monthly":"FREQ=MONTHLY","yearly":"FREQ=YEARLY"}

def esc(s):
    return s.replace("\\","\\\\").replace(";","\\;").replace(",","\\,").replace("\n","\\n")

def alarm_trigger(v):
    m = ALARM_RE.match(v.strip())
    if not m: return None
    n, u = m.group(1), m.group(2)
    return f"-P{n}D" if u=="d" else f"-PT{n}{'H' if u=='h' else 'M'}"

def parse_line(line):
    s = line.strip()
    if not (s.startswith("- [ ]") or s.startswith("- [x]") or s.startswith("- [X]")):
        return None
    tags = dict(TAG_RE.findall(s))
    if "uid" not in tags or "due" not in tags:
        return None
    body = TAG_RE.sub("", s[5:])                      # nach Checkbox, Tags raus
    cats = HASH_RE.findall(body)
    title = HASH_RE.sub("", body).strip(" -\t").strip()
    return {"uid":tags["uid"].strip(), "due":tags["due"].strip(),
            "end":tags.get("end","").strip(), "title":title or "(ohne Titel)",
            "alarms":[a for a in (alarm_trigger(x) for x in re.findall(r'@alarm\(([^)]*)\)', s)) if a],
            "rrule":tags.get("rrule","").strip(), "cats":cats}

def fmt_due(due):
    m = DUE_DT.match(due)
    if not m: return None
    y,mo,d,hh,mm = m.groups()
    if hh is None:
        return ("DATE", f"{y}{mo}{d}", f"{y}{mo}{d}")     # all-day
    return ("DT", f"{y}{mo}{d}T{hh}{mm}00", f"{y}{mo}{d}")

def build(ev):
    f = fmt_due(ev["due"])
    if not f: return None
    kind, dtval, daystamp = f
    L = ["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//kb//gen_ics//DE","CALSCALE:GREGORIAN", VTIMEZONE,
         "BEGIN:VEVENT", f"UID:{ev['uid']}@kb", f"DTSTAMP:{daystamp}T000000Z",
         "SEQUENCE:0", f"SUMMARY:{esc(ev['title'])}"]
    if kind == "DATE":
        L.append(f"DTSTART;VALUE=DATE:{dtval}")
    else:
        L.append(f"DTSTART;TZID=Europe/Berlin:{dtval}")
        if ev["end"]:
            em = re.match(r'^(\d{2}):(\d{2})$', ev["end"])
            if em:
                L.append(f"DTEND;TZID=Europe/Berlin:{dtval[:9]}{em.group(1)}{em.group(2)}00")
            else:
                fe = fmt_due(ev["end"])
                if fe and fe[0]=="DT": L.append(f"DTEND;TZID=Europe/Berlin:{fe[1]}")
    if ev["rrule"]:
        L.append("RRULE:" + RRULE_MAP.get(ev["rrule"].lower(), ev["rrule"]))
    if ev["cats"]:
        L.append("CATEGORIES:" + ",".join(esc(c) for c in ev["cats"]))
    for tr in ev["alarms"] or (["-PT15M"] if kind=="DT" else []):
        L += ["BEGIN:VALARM","ACTION:DISPLAY", f"DESCRIPTION:{esc(ev['title'])}", f"TRIGGER:{tr}","END:VALARM"]
    L += ["END:VEVENT","END:VCALENDAR"]
    return "\r\n".join(L) + "\r\n"

def main():
    os.makedirs(OUT, exist_ok=True)
    if not os.path.exists(TASKS):
        return
    n = 0
    with open(TASKS, encoding="utf-8") as fh:
        for line in fh:
            ev = parse_line(line)
            if not ev: continue
            ics = build(ev)
            if not ics:
                sys.stderr.write(f"gen_ics: ungültiges @due in: {line.strip()}\n"); continue
            path = os.path.join(OUT, f"{ev['uid']}.ics")
            old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
            if old != ics:
                with open(path, "w", encoding="utf-8") as o: o.write(ics)
            n += 1
    print(f"gen_ics: {n} aktive Events")

if __name__ == "__main__":
    main()
