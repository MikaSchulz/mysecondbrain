# Tasks & Termine (Single Source)

Aktive Tasks/Termine. Format pro Zeile:
`- [ ] Titel @uid(KURZID) @due(YYYY-MM-DD HH:MM) @end(HH:MM) @alarm(15m) @rrule(weekly) #tag`

- `@uid` persistent (nie ändern). `@due` ohne Uhrzeit = all-day. `[x]` = erledigt.
- `gen_ics.py` erzeugt daraus Kalender-Events. Absage → UID nach `.cancel-events`.

## Offen

> Format-Beispiel (KEIN echter Task — Zeile beginnt mit `>`, wird ignoriert):
> `- [ ] Beispieltermin @uid(a1b2c3) @due(2026-06-10 14:00) @alarm(15m) #demo`
