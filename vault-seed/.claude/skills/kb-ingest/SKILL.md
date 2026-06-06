---
name: kb-ingest
description: MANUELL/INTERAKTIV (Knowledge-Lane). Tiefe Quellen aus knowledge-inbox/ kuratiert ins Wiki einarbeiten. Nutzen NUR in interaktiven Sessions (besseres Modell, Abo-Limits) — NICHT im headless cron.
---

# kb-ingest (Knowledge-Lane, manuell)

**Wann**: du startest `claude` interaktiv (NUC oder PC, gesyncter Vault) für tiefe Artikel/PDFs/Research.
Läuft über interaktive Abo-Limits, NICHT den Headless-Pool. Besseres Modell (Sonnet/Opus) erlaubt.

**Input**: Quellen in `knowledge-inbox/`.

**Tun**:
1. Quelle gründlich lesen → mehrere atomare, gut verlinkte `wiki/`-Seiten (mehr Tiefe als Fast-Lane).
   Frontmatter + reichhaltige `[[links]]`; bestehende Seiten via Grep erweitern.
2. `index.md`-MOCs (unter AUTO-Marker) kuratieren — Themen-Landkarten pflegen.
3. Quelle → `knowledge-processed/`. `log.md` anhängen.

**Grenzen**: hier darfst du `knowledge-inbox/` + `knowledge-processed/` lesen/schreiben (interaktiv,
nicht durch headless-settings.json eingeschränkt). Sorgfalt > Geschwindigkeit.
