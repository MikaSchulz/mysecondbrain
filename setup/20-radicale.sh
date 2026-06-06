#!/usr/bin/env bash
# 20-radicale.sh — Radicale (CalDAV) im venv + systemd. Bind 0.0.0.0:5232 (LXC nicht port-geforwardet
# -> nur LAN+Tailnet erreichbar). User/Passwort aus /opt/kb/.env. Collection wird beim 1. PUT erstellt.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
source /opt/kb/.env 2>/dev/null || true
RUSER="${RADICALE_USER:-kb}"; RPW="${RADICALE_PW:?RADICALE_PW in /opt/kb/.env setzen}"

apt-get update -y
apt-get install -y apache2-utils python3-venv python3-pip
python3 -m venv /opt/radicale-venv
/opt/radicale-venv/bin/pip install --upgrade pip >/dev/null
/opt/radicale-venv/bin/pip install "radicale" "passlib[bcrypt]" "bcrypt" >/dev/null

mkdir -p /etc/radicale /var/lib/radicale/collections
htpasswd -cbB /etc/radicale/users "$RUSER" "$RPW"
chmod 640 /etc/radicale/users

cat > /etc/radicale/config <<'CFG'
[server]
hosts = 0.0.0.0:5232
[auth]
type = htpasswd
htpasswd_filename = /etc/radicale/users
htpasswd_encryption = bcrypt
[storage]
filesystem_folder = /var/lib/radicale/collections
CFG

id radicale >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin radicale
chown -R radicale:radicale /var/lib/radicale /etc/radicale/users

cat > /etc/systemd/system/radicale.service <<'UNIT'
[Unit]
Description=Radicale CalDAV/CardDAV
After=network.target
[Service]
ExecStart=/opt/radicale-venv/bin/radicale --config /etc/radicale/config
User=radicale
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now radicale
sleep 2
echo ">> Radicale läuft auf :5232 (User $RUSER)."
echo ">> Collection '${RADICALE_CALENDAR:-routine}' wird beim ersten sync-caldav-PUT automatisch angelegt."
echo ">> Geräte-CalDAV-URL: http://kb.<tailnet>.ts.net:5232/$RUSER/${RADICALE_CALENDAR:-routine}/"
curl -sf -u "$RUSER:$RPW" "http://localhost:5232/" -o /dev/null && echo ">> Healthcheck localhost OK" || echo ">> WARN: localhost-Check fehlgeschlagen"
