# setup/ — Dienst-Setup auf dem NUC (LXC), nach `install.sh`

Reihenfolge (alle als root, im kb-LXC):

```bash
# Voraussetzung: install.sh lief, /opt/kb/.env ausgefüllt (RADICALE_PW etc.), claude setup-token erledigt.

sudo bash setup/10-tailscale.sh     # eigener Tailnet-Node (braucht /dev/net/tun, siehe Header)
sudo bash setup/20-radicale.sh      # CalDAV :5232 + User aus .env
sudo bash setup/30-ntfy.sh          # ntfy :8080 + Token -> wird in .env geschrieben
sudo bash setup/40-whisper.sh small # Speech-to-Text (Phase 2; small od. medium für DE)
sudo bash setup/50-syncthing.sh     # Vault-Sync, GUI nur aufs Tailnet
```

Danach:
```bash
DRY_RUN=1 /opt/kb/run.sh    # Pipeline simulieren
/opt/kb/run.sh             # echter Lauf (claude über Abo-Pool)
env | grep ANTHROPIC       # MUSS leer sein -> Abo-Billing
```

## Exposure / Bind
- Radicale (:5232) + ntfy (:8080) binden auf `0.0.0.0`, aber der LXC ist **nicht** port-geforwardet
  → faktisch nur LAN + Tailnet. Strenger: in den Configs auf die Tailscale-IP binden.
- Syncthing-GUI bindet nur auf die Tailscale-IP.
- Geräte adressieren alles über `kb.<tailnet>.ts.net`.

## Reihenfolge-Hinweise
- `30-ntfy.sh` patcht `NTFY_TOKEN` in `/opt/kb/.env` automatisch.
- `40-whisper.sh` patcht `WHISPER_BIN`/`WHISPER_MODEL` in `/opt/kb/.env`.
- Nach `claude setup-token`: `date +%F > /opt/kb/.token-installed` (für Renewal-Reminder).

## Phase 3 (später, separat)
- OpenWA (WhatsApp) — eigener Service, schreibt nach `raw/audio` + `raw/chats` (ToS-Risiko, Zweitnummer).
- DAVx5/SyncTrain/Obsidian auf den Geräten einrichten.
