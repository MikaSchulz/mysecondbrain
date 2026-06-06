---
name: appointment-extract
description: Extrahiert Termine und Fristen aus beliebigem Text zu strukturierten tasks.md-Zeilen. Nutzen, wenn eine Quelle zeitbezogene Angaben enthält (Treffen, Deadline, Erinnerung).
---

# appointment-extract

**Input**: beliebiger Text + Quell-Datum (Frontmatter `date:` der Rohquelle = Basis für relative Angaben).

**Tun**: jede Termin-/Frist-Angabe → eine Zeile in `tasks.md`:
```
- [ ] Titel @uid(KURZID) @due(YYYY-MM-DD HH:MM) @end(HH:MM) @alarm(15m) #quelle
```
- Relative Angaben ("morgen", "nächsten Dienstag 15 Uhr") gegen `date:` auflösen, nicht gegen heute.
- `@uid` neu vergeben (zufällige 6-stellige ID), persistent.
- all-day ohne Uhrzeit. Default-Alarm `@alarm(15m)` wenn nichts angegeben.
- Unsicher ob Termin? → nicht raten, im Wiki vermerken statt falschen Kalendereintrag.

KEINE `.ics`. Das macht `gen_ics.py` aus `tasks.md`.
