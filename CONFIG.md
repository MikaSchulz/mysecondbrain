# CONFIG — zentrale Einrichtung (alles an einem Ort)

Ziel: einmal `kb-configure` durchklicken, fertig. `kb-doctor` zeigt jederzeit, was fehlt.

```
sudo bash install.sh      # kopiert alles nach /opt/kb, cron + Watcher
sudo kb-configure         # ZENTRALER Wizard (Menü)
kb-doctor                 # Status-Check
```

`kb-configure`-Menü:
| # | Schritt | Was passiert | Interaktiv? |
|---|---|---|---|
| 1 | .env Grunddaten | Radicale-PW, ntfy-Topic, Budget, Modell → `/opt/kb/.env` | Eingaben |
| 2 | Claude Abo-Token | `claude setup-token`, Token → `.env`, `ANTHROPIC_API_KEY` entfernt | Browser-URL + Token einfügen |
| 3 | Tailscale-Login | `tailscale up` (eigener Node) | Auth-URL öffnen |
| 4 | Dienste | Radicale + ntfy (+whisper) + Syncthing installieren | ja/nein-Fragen |
| 5 | WhatsApp | OpenWA installieren + Start | QR scannen |
| 6 | Doctor | Status-Übersicht | – |
| 7 | Alles 1–4 + 6 | der Reihe nach | – |

---

## Was wird WO eingetragen? (Überblick, falls manuell)

| Login / Config | Befehl / Ort | Landet in |
|---|---|---|
| **Claude (Abo)** | `claude setup-token` | `/opt/kb/.env` → `CLAUDE_CODE_OAUTH_TOKEN` (+ `/opt/kb/.token-installed`) |
| **Tailscale** | `tailscale up` (im kb-LXC) | Tailnet-Node `kb.<tailnet>.ts.net` |
| **Radicale** | `setup/20-radicale.sh` | User/PW aus `.env` (`RADICALE_USER/PW`), htpasswd |
| **ntfy** | `setup/30-ntfy.sh` | Token automatisch → `.env` (`NTFY_TOKEN`) |
| **whisper** | `setup/40-whisper.sh` | Pfade automatisch → `.env` (`WHISPER_BIN/MODEL`) |
| **Syncthing** | `setup/50-syncthing.sh` + GUI | Geräte-Pairing in der GUI (`http://<tailscale-ip>:8384`) |
| **WhatsApp** | `setup/60-openwa.sh` → QR | Session in `/opt/kb-openwa/sessions` |
| **Budgets/Caps** | `.env` | `MONTH_BUDGET_USD`, `MIN_AGE`, `MAX_RUNS_DAY` … |

**Eine Datei für Secrets:** `/opt/kb/.env` (chmod 600). Sonst nichts verstreut.

---

## ⚠️ Kritisch: Abo-Billing (nicht API!)
- Nur `CLAUDE_CODE_OAUTH_TOKEN` setzen. **`ANTHROPIC_API_KEY` NIE.** (`kb-doctor` warnt.)
- Overflow-Billing im Anthropic-Account AUS → harte Decke ($20 Pro-Pool/Monat).

## Geräte (einmalig, pro Gerät)
- **Tailscale-App** installieren + einloggen (gleiches Tailnet).
- **Kalender**: CalDAV-Account `http://kb.<tailnet>.ts.net:5232/<user>/routine/` (iOS nativ / Android DAVx5 / Win Thunderbird).
- **ntfy-App**: Server `http://kb.<tailnet>.ts.net:8080`, Topic + Token.
- **Obsidian** + Vault-Sync: Android Syncthing(-Fork) / iOS SyncTrain / Win-Mac Syncthing. Kein Obsidian-Abo.

## Proxmox-Host (einmalig, falls noch nicht)
- `/dev/net/tun` in den LXC durchreichen (für Tailscale) — siehe `setup/10-tailscale.sh` Header.

## Verifikation
```
kb-doctor                 # alles grün?
DRY_RUN=1 /opt/kb/run.sh  # Pipeline ohne claude/CalDAV
/opt/kb/run.sh            # echter Lauf
env | grep ANTHROPIC      # MUSS leer sein
```
