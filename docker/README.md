# Docker — mysecondbrain als Container

Gleicher App-Kern wie die LXC-Variante (`/opt/kb`-Skripte, Vault, run.sh, Dienste) — nur
**supervisord statt systemd**. All-in-One-Image: Radicale + ntfy + Syncthing + Tailscale + cron + Watcher.

## Start

```bash
git clone git@github.com:MikaSchulz/mysecondbrain.git && cd mysecondbrain
cp .env.docker.example .env.docker
# .env.docker ausfüllen: CLAUDE_CODE_OAUTH_TOKEN (claude setup-token), Passwörter, optional TS_AUTHKEY
docker compose up -d --build
docker compose logs -f          # Tailscale-QR/Status, ntfy/radicale-Logs
docker compose exec mysecondbrain kb-doctor
```

## Ports (auf den Host gemappt)
| Port | Dienst |
|---|---|
| 5232 | Radicale CalDAV |
| 8080 | ntfy |
| 8384 | Syncthing GUI |

Zugriff: über den **Tailnet-Namen** (wenn `TS_AUTHKEY` gesetzt → Container joint Tailnet) oder über
`host-ip:port`. Ohne Tailscale die Ports nur im LAN/über die Host-Tailscale erreichbar.

## Daten / Persistenz
Alles in Volume `kb-data` → `/data` (vault, radicale, ntfy, syncthing, tailscale-state, `.env`).
Vault liegt unter `/data/vault` (git-versioniert). Backup = Volume sichern (oder `restic` via `backup.sh`).

## Parameter (`.env.docker`)
| Var | Zweck |
|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Abo-Token (`claude setup-token`). **KEIN `ANTHROPIC_API_KEY`!** |
| `RADICALE_USER/PW` | CalDAV-Login |
| `NTFY_USER/PASSWORD/TOPIC` | Push (Basic-Auth) |
| `TS_AUTHKEY` / `TS_HOSTNAME` | Tailscale (optional) |
| `KB_MODEL`, `MONTH_BUDGET_USD`, `MIN_AGE`, `MAX_RUNS_DAY` | Modell + Kosten/Caps |
| Build-Arg `WITH_WHISPER=true` | whisper.cpp ins Image (Voice) |

## Tailscale
Braucht `cap_add: NET_ADMIN` + `/dev/net/tun` (in compose gesetzt). Ohne TUN läuft alles weiter,
nur das Tailnet-Join entfällt (dann Ports via Host erreichbar). Auth via `TS_AUTHKEY`.

## WhatsApp (OpenWA, optional/experimentell)
Im Container: `docker compose exec mysecondbrain bash /opt/kb/setup/60-openwa.sh` (QR scannen).
ToS-Risiko (Zweitnummer). Alternativ als eigener Service.

## Befehle im Container
```bash
docker compose exec mysecondbrain kb-doctor
docker compose exec mysecondbrain kb-configure
docker compose exec mysecondbrain bash -lc 'DRY_RUN=1 /opt/kb/run.sh'
```
