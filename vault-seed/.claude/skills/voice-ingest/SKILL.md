---
name: voice-ingest
description: Verarbeitet transkribierte Sprachnachrichten aus raw/audio/ (whisper.cpp hat bereits Text erzeugt) zu wiki-Seiten plus Tasks/Terminen. Nutzen, wenn eine transkribierte raw/audio/*.md Quelle vorliegt.
---

# voice-ingest

**Input**: Transkript (`raw/audio/<name>.md`, Frontmatter `from`, `date`, `sources` = Audio-Datei).

**Tun**:
1. Transkript verdichten → atomare `wiki/`-Seite(n), terse. Frontmatter + `[[links]]`.
2. Genannte To-dos/Termine → `tasks.md` (`@uid`/`@due`/`@alarm`, Datum relativ zu `date:`).
3. Quelle (Transkript + Audioverweis) → `tmp/`. 1 Zeile `log.md`.

**Grenzen**: Transkripte sind fehlerbehaftet — bei unklaren Namen/Daten nicht raten, im Wiki als unsicher markieren.
