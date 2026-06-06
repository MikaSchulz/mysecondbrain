#!/usr/bin/env bash
# 50-syncthing.sh — Syncthing für Vault-Sync. GUI nur aufs Tailnet gebunden. Pairing manuell.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"

command -v syncthing >/dev/null || { apt-get update -y; apt-get install -y syncthing; }

# GUI nur aufs Tailnet (sonst LAN-Exposure ohne Auth). Fallback localhost.
TSIP="$(tailscale ip -4 2>/dev/null | head -1 || true)"; [ -z "$TSIP" ] && TSIP="127.0.0.1"
mkdir -p /etc/systemd/system/syncthing@root.service.d
cat > /etc/systemd/system/syncthing@root.service.d/override.conf <<EOF
[Service]
Environment=STGUIADDRESS=$TSIP:8384
EOF

# Syncthing-ignore im Vault (kein .git/Cache/transient syncen)
cat > "$VAULT/.stignore" <<'IGN'
.git
.cache
.stversions
.last_out
.last_run
.seen
IGN

systemctl daemon-reload
systemctl enable --now syncthing@root
sleep 3
echo ">> Syncthing läuft. GUI: http://$TSIP:8384  (übers Tailnet)."
echo ">> Schritte: GUI öffnen -> Ordner '$VAULT' (ID: kb-vault) hinzufügen/teilen -> Geräte koppeln."
echo ">> Geräte: Android=Syncthing(-Fork), iOS=SyncTrain/Möbius, Win/Mac=Syncthing. Vault in Obsidian öffnen."
echo ">> GUI-Passwort in der Syncthing-Oberfläche setzen (Actions->Settings->GUI)."
