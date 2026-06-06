# Second Brain — Vault-Regeln (Karpathy-Prinzip)

Du pflegst diesen Vault. **Terse**: Artikel/Füllwörter weg, dichte Seiten (Token sparen).
Sprache: Deutsch, Tech-Begriffe englisch lassen.

## Struktur — was du anfassen darfst
- `raw/`     Rohquellen. NUR lesen. Nach Verarbeitung Datei selbst nach `tmp/` verschieben (= erledigt-Marker).
- `wiki/`    Deine Seiten. Hier schreiben, aktualisieren, `[[verlinken]]`.
- `index.md` Katalog. IMMER zuerst lesen. NUR außerhalb der `<!-- AUTO:start -->…<!-- AUTO:end -->`-Marker schreiben.
- `log.md`   Append-only. NUR ans Ende anhängen. NIE ganz laden.
- `tasks.md` Tasks + Termine als strukturierte Zeilen (siehe unten).
- `tmp/`     Staging für verarbeitete Rohdateien.
- Handoffs:  `.stale`, `.archive-tasks`, `.cancel-events` (du schreibst Zeilen rein, Skripte handeln).

**NICHT anfassen** (Skript-only): `archive/`, `processed/`, `knowledge-inbox/`, `knowledge-processed/`, `out/`.

## Drei Operationen
- **Ingest**: neue `raw/`-Quelle → atomare `wiki/`-Seite(n) bauen, `index.md` + `log.md` aktualisieren,
  Quelle → `tmp/` verschieben.
- **Query**: `index.md` lesen → passende Seite via Grep → Antwort mit Quellenbezug.
- **Lint**: Widersprüche / veraltete Infos / tote `[[links]]` finden → markieren.

## Regeln Wiki
- Lieber viele kleine atomare Seiten als wenige große.
- Frontmatter Pflicht: `title`, `tags`, `sources`, `created`, `updated`. Plus `[[links]]` zu verwandten Seiten.
- Bestehende Seite via Grep finden + erweitern statt Duplikat anlegen.
- Jede Aussage muss auf eine `raw/`-Quelle rückführbar sein (`sources:` → processed-Pfad). Bei Unsicherheit: fragen, nicht raten.

## Regeln Tasks/Termine (`tasks.md`)
Format pro Zeile:
```
- [ ] Titel @uid(KURZID) @due(YYYY-MM-DD HH:MM) @end(HH:MM) @alarm(15m) @rrule(weekly) #tag
```
- `@uid(...)` **persistent**: einmal vergeben, NIE ändern (sonst Kalender-Duplikat). Neue Tasks: zufällige 6-stellige ID.
- all-day: `@due(YYYY-MM-DD)` ohne Uhrzeit. Mehrere `@alarm()` erlaubt. `@end`/`@rrule` optional.
- Erledigt: `- [x]`. Termin **absagen** (aus Kalender entfernen): UID-Zeile nach `.cancel-events` schreiben.
- KEINE `.ics` schreiben — das macht `gen_ics.py`.

## Veraltetes
- Veraltetes Wissen / Widerspruch: Zeile `wiki/<pfad>.md superseded-by wiki/<neu>.md` nach `.stale`.
- NICHT löschen, NICHT nach archive/ schreiben — Skripte verschieben.
