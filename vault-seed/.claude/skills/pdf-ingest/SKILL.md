---
name: pdf-ingest
description: Verarbeitet PDF-Text aus raw/pdf/ (bereits via pdftotext/OCR extrahiert) zu atomaren wiki-Seiten plus extrahierten Tasks/Terminen. Nutzen, wenn eine raw/pdf/*.txt oder .md Quelle vorliegt.
---

# pdf-ingest

**Input**: extrahierter PDF-Text (`raw/pdf/<name>.txt` o. `.md`, Frontmatter mit `sources`, `date`).

**Tun**:
1. Inhalt zusammenfassen → eine oder mehrere atomare `wiki/`-Seiten (je Thema eine), terse.
   Frontmatter: title, tags, sources (Pfad der Quelle), created, updated. `[[links]]` zu Verwandtem (vorher Grep).
2. Enthält der Text Termine/Fristen/To-dos → Zeilen in `tasks.md`:
   `- [ ] Titel @uid(KURZID) @due(YYYY-MM-DD HH:MM) @alarm(15m) #pdf`. Datum relativ zu `date:` der Quelle.
3. Quelle nach `tmp/` verschieben. 1 Zeile nach `log.md`.

**Grenzen**: große PDFs gedanklich chunken; nur Wesentliches ins Wiki. Keine `.ics` schreiben.
