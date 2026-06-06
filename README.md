# mysecondbrain — Souveränes Second-Brain & Task-System (NUC / Proxmox LXC)

Deploybares Bootstrap-Repo. Erzeugt auf dem NUC:
- `/opt/kb/` — Skripte + `.env` (Secrets)
- `/opt/kb/vault/` — der Markdown-Vault (Second Brain, git-versioniert)

Lokaler `claude -p` (headless, **über Pro-Abo via OAuth-Token**) verarbeitet neue Inputs,
pflegt ein Markdown-Wiki, erzeugt Tasks/Termine → CalDAV (Radicale) + Push (ntfy).
**LLM = eine Stufe, alles Mechanische = deterministische Skripte.**

**Zwei Wege, gleicher App-Kern** (`opt-kb/` + `vault-seed/`): als **Proxmox-LXC** (systemd) oder als
**Docker-Container** (supervisord). Nur die Packaging-Schicht unterscheidet sich.

## Layout dieses Repos

```
opt-kb/        → wird nach /opt/kb/ kopiert (Skripte + .env.template)  [Kern]
vault-seed/    → initialer Vault (raw/wiki/index/log/tasks, CLAUDE.md, Skills)  [Kern]
setup/         → Dienst-Setup für LXC (Tailscale/Radicale/ntfy/whisper/Syncthing)
install.sh     → LXC: Dirs, Kopie, git, cron, systemd-watcher
proxmox/       → install-lxc.sh: One-Shot-LXC vom Proxmox-Host
docker/        → Dockerfile + entrypoint + supervisord  (Docker-Variante)
docker-compose.yml → Docker-Start
selftest.sh    → verifiziert die deterministische Pipeline lokal (kein claude/Netz nötig)
```

## Schnellstart: Docker

```bash
git clone git@github.com:MikaSchulz/mysecondbrain.git && cd mysecondbrain
cp .env.docker.example .env.docker     # ausfüllen: CLAUDE_CODE_OAUTH_TOKEN, PWs, optional TS_AUTHKEY
docker compose up -d --build
docker compose exec mysecondbrain kb-doctor
```
Details: **docker/README.md**.

## Schnellstart: Proxmox-LXC (empfohlen, out of the box)

Auf dem **Proxmox-Host** (root) — erstellt Container + provisioniert alles:
```bash
git clone git@github.com:MikaSchulz/mysecondbrain.git
bash mysecondbrain/proxmox/install-lxc.sh   # fragt paar Params (Token, Authkey, PW ...)
```
Details + Params + unattended: **proxmox/README.md**.

---

## Manuell in einem bestehenden LXC

```bash
# 1. Repo auf den NUC bringen (scp/git), dann:
sudo bash install.sh      # Pakete + Claude CLI, kopiert alles nach /opt/kb, cron + Watcher

# 2. ZENTRAL konfigurieren (ein Wizard für alles):
sudo kb-configure         # .env, Claude-Token, Tailscale, Dienste, WhatsApp
kb-doctor                 # Status: was läuft, was fehlt

# 3. Smoke-Test:
DRY_RUN=1 /opt/kb/run.sh  # simuliert ohne claude/CalDAV
/opt/kb/run.sh            # echter Lauf
```

**Alle Logins/Configs zentral:** `kb-configure` (Menü) → Details in **CONFIG.md**.
Einzelne Dienst-Skripte liegen in `setup/` (vom Wizard aufgerufen).

## ⚠️ Abo-Billing absichern (sonst API-Kosten!)
- `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN`. **`ANTHROPIC_API_KEY` NIE setzen.**
- Prüfen: `env | grep ANTHROPIC` muss leer sein.
- Overflow-Billing im Anthropic-Account AUS lassen → harte Decke.

## MVP-Phasing
- **Phase 1 (dieses Repo)**: Text/PDF-Ingest → wiki + tasks.md → Radicale + ntfy + guard/Kosten.
- **Phase 2**: whisper.cpp + ffmpeg (Voice), Syncthing + Obsidian-Geräte.
- **Phase 3**: OpenWA (WhatsApp), kb-ingest (Knowledge-Lane), Hygiene-Crons.

## Skripte (`/opt/kb/`)
| Skript | Zweck |
|---|---|
| `run.sh` | Orchestrator (guard → prep → claude → POST) |
| `guard.sh` | 30-min-Sammelfenster + Cooldown + Tages-Cap + Monats-Budget |
| `prep-raw.sh` | raw/ klassifizieren, PDF→Text, Dedup |
| `tasks-changed.sh` | fällige/geänderte Tasks → Empty-Gate |
| `move-processed.sh` | tmp/ → processed/ |
| `archive-stale.sh` | `.stale` → archive/stale/ |
| `archive-tasks.sh` | `.archive-tasks` → archive/tasks-* |
| `tidy-tasks.sh` | erledigte/vergangene Tasks → archive (Kalender bleibt) |
| `index-assist.sh` | index.md AUTO-Block regenerieren |
| `plan.sh` | tasks.md → out/plan.md |
| `gen_ics.py` | tasks.md → out/events/*.ics (Europe/Berlin) |
| `sync-caldav.sh` | PUT geänderte; DELETE nur `.cancel-events` |
| `cost-watch.sh` | usage aus .last_out → Monats-$-Tally |
| `kb-ask` | on-demand Query gegen index.md |
| `kb-ingest` | manuell-interaktive Knowledge-Lane |
| `watch-raw.sh` | inotify auf raw/urgent → sofort run.sh |
