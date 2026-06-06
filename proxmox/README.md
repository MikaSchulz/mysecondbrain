# Proxmox-LXC Installer — out of the box

Ein Skript auf dem **Proxmox-Host**: fragt ein paar Parameter, erstellt den LXC, provisioniert alles,
fertig. Der Container läuft danach eigenständig (cron + Watcher + Dienste).

## Install (auf dem Proxmox-Host, als root)

**Community-One-Liner** (Repo muss public sein) — lädt Skript + Repo automatisch von GitHub:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/MikaSchulz/mysecondbrain/main/proxmox/install-lxc.sh)"
```

Oder aus lokalem Checkout (dev):
```bash
git clone git@github.com:MikaSchulz/mysecondbrain.git
bash mysecondbrain/proxmox/install-lxc.sh
```

Quelle steuerbar: `KB_REPO=user/repo KB_BRANCH=main` (Default `MikaSchulz/mysecondbrain@main`).
Der Installer nutzt einen lokalen Checkout falls vorhanden, sonst lädt er das Repo-Tarball von GitHub
in den LXC (kein git/SSH im Container nötig).

Abgefragt:
| Param | Default | Zweck |
|---|---|---|
| CTID | nextid | Container-ID |
| Hostname | kb | LXC-Name |
| Cores / RAM / Disk | 2 / 4096 / 20 | Ressourcen (whisper+Node brauchen etwas) |
| Storage / Bridge | local-lvm / vmbr0 | rootfs / Netz |
| Timezone | Europe/Berlin | – |
| **Claude OAuth-Token** | – | `claude setup-token` (auf bel. Rechner); leer = später im Container |
| **Tailscale Auth-Key** | – | `tskey-...` aus Tailscale Admin → Settings → Keys; leer = später interaktiv |
| **Radicale-Passwort** | random | CalDAV-Login |
| **ntfy-Passwort** | random | Push-Login |
| ntfy-Topic | kb | – |
| whisper bauen? | no | Voice (Phase 2); dauert beim Build |

Der Installer: lädt Debian-12-Template, `pct create` (unprivileged, nesting=1, `/dev/net/tun` für
Tailscale), kopiert das Repo rein, `install.sh` + `configure.sh unattended`.

## Unattended (ohne Prompts)

```bash
CTID=210 NONINTERACTIVE=1 \
RADICALE_PW='geheim' NTFY_PASSWORD='geheim' NTFY_TOPIC=kb \
CLAUDE_CODE_OAUTH_TOKEN='...' TS_AUTHKEY='tskey-...' WITH_WHISPER=no \
bash mysecondbrain/proxmox/install-lxc.sh
```

## Voraussetzungen
- Proxmox VE, Internet im LXC (DHCP), Debian-12-Template (wird automatisch geladen).
- **Tailscale-Authkey**: Tailscale-Admin → Settings → Keys → Generate (reusable/ephemeral nach Wahl).
- **Claude-Token**: `claude setup-token` (Abo-OAuth, KEIN API-Key) — Token in den Installer einfügen.

## Danach
```bash
pct enter <CTID>
kb-doctor                       # Status
kb-configure                    # Nachkonfig (falls Token/Authkey leer gelassen)
bash /opt/kb/setup/60-openwa.sh # optional: WhatsApp (QR scannen), experimentell
```
Geräte erreichen die Dienste über den Tailnet-Namen `kb.<tailnet>.ts.net`:
CalDAV `:5232`, ntfy `:8080`, Syncthing-GUI `:8384`.

## Hinweise
- Repo ist privat → der Installer nutzt die **lokale Kopie** auf dem Host (kein GitHub-Zugriff im LXC nötig).
- Abo-Billing-Schutz: `ANTHROPIC_API_KEY` wird nie gesetzt; `kb-doctor` warnt sonst.
