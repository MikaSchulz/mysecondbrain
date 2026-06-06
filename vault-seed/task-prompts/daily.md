# Daily Routine

Befolge `CLAUDE.md`. **NICHT** den ganzen Vault lesen — `index.md` zuerst, dann gezielt via Grep.
Terse arbeiten (Token sparen).

1. Lies `index.md` (Katalog) + alle neuen Dateien in `raw/` (rekursiv) + `tasks.md`. `log.md` NICHT laden.
2. **Ingest**: für jede neue `raw/`-Quelle eine atomare `wiki/`-Seite bauen
   (Frontmatter: title, tags, sources, created, updated; plus `[[links]]` zu verwandten Seiten).
   Bestehende Seite via Grep finden & erweitern statt Duplikat.
3. `index.md` aktualisieren (nur innerhalb der AUTO-Marker NICHT — die macht das Skript;
   semantische Gruppierungen außerhalb). `log.md` mit 1 Zeile pro Aktion anhängen.
4. **Tasks/Termine** aus den Quellen → `tasks.md` pflegen:
   `- [ ] Titel @uid(KURZID) @due(YYYY-MM-DD HH:MM) @alarm(15m)`.
   Relative Angaben ("morgen 15 Uhr") gegen das Quell-Datum (Frontmatter `date:`) auflösen.
   KEINE `.ics` schreiben.
5. **Jede verarbeitete Quelle** SELBST von `raw/` nach `tmp/` verschieben (= erledigt-Marker).
6. Veraltetes/Widersprüche → Zeile nach `.stale`. Echte Termin-Absage → Zeile nach `.cancel-events`.

Du darfst NUR: `raw/` lesen+rausschieben, `wiki/`, `index.md`, `tasks.md`, `log.md`, `tmp/`, Handoffs.
NICHT: `archive/`, `processed/`, `knowledge-*`, `out/`. `out/plan.md` baut ein Skript — nicht du.
