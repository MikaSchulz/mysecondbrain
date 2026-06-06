---
name: chat-analysis
description: Wertet Chat-Exporte aus raw/chats/ aus — Kernpunkte/Entscheidungen zusammenfassen, Tasks und Termine extrahieren. Nutzen bei WhatsApp/Telegram/Signal-Exporten.
---

# chat-analysis

**Input**: Chat-Export (`raw/chats/<name>.md`, Frontmatter `from`, `date`, `chat`).

**Tun**:
1. Kernpunkte/Entscheidungen/offene Fragen knapp zusammenfassen → `wiki/`-Seite(n), terse.
   Frontmatter + `[[links]]` (verwandte Personen/Projekte vorher Grep).
2. To-dos/Termine → `tasks.md` (`@uid`/`@due`/`@alarm`, Datum relativ zu `date:`).
3. Quelle → `tmp/`. 1 Zeile `log.md`.

**Grenzen**: lange Chats verdichten, kein Wort-für-Wort-Dump. Privat behandeln (alles bleibt lokal).
