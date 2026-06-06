#!/usr/bin/env bash
# 60-openwa.sh — OpenWA (WhatsApp-Capture) installieren. EXPERIMENTELL, gegen WhatsApp-ToS (Sperr-Risiko).
# Zweitnummer empfohlen. Login = QR scannen (erscheint in den Logs beim ersten Start).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
SRC="$(cd "$(dirname "$0")/.." && pwd)"     # mysecondbrain-Wurzel (oder /opt/kb falls dort)
APP=/opt/kb-openwa

echo "!! WhatsApp-Automation ist inoffiziell und kann zur Sperrung führen. Zweitnummer nutzen. Weiter? [y/N]"
read -r a; [ "${a,,}" = y ] || { echo "abgebrochen"; exit 0; }

# Node + Chromium (für puppeteer headless)
command -v node >/dev/null || { apt-get update -y; apt-get install -y nodejs npm; }
apt-get install -y chromium ca-certificates fonts-liberation \
  libnss3 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libxkbcommon0 \
  libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 libpangocairo-1.0-0 2>/dev/null || true

mkdir -p "$APP/sessions"
# listener + package.json bereitstellen (aus Repo openwa/ oder /opt/kb/openwa/)
for cand in "$SRC/openwa" "/opt/kb/openwa"; do
  if [ -f "$cand/listener.js" ]; then install -m 0644 "$cand/listener.js" "$cand/package.json" "$APP/"; break; fi
done
[ -f "$APP/listener.js" ] || { echo "FEHLER: openwa/listener.js nicht gefunden"; exit 1; }

cd "$APP"
PUPPETEER_SKIP_DOWNLOAD=1 npm install --omit=dev

# systemd-Unit
for cand in "$SRC/systemd/kb-openwa.service" "/opt/kb/systemd/kb-openwa.service"; do
  [ -f "$cand" ] && { install -m 0644 "$cand" /etc/systemd/system/kb-openwa.service; break; }
done
systemctl daemon-reload
systemctl enable --now kb-openwa

cat <<EOF

>> OpenWA gestartet. JETZT QR scannen:
   journalctl -u kb-openwa -f
   (WhatsApp -> Verknüpfte Geräte -> Gerät verknüpfen -> QR aus den Logs scannen)
>> Danach: Sprachnachrichten -> raw/audio/, Chats -> raw/chats/  (run.sh verarbeitet sie).
>> Stoppen: systemctl stop kb-openwa
EOF
