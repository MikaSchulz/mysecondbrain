#!/usr/bin/env bash
# 30-ntfy.sh — ntfy-Server (statisches Binary, kein apt-Repo) + Basic-Auth + systemd. Bind 0.0.0.0:8080.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
ENVF=/opt/kb/.env
source "$ENVF" 2>/dev/null || true
NUSER="${NTFY_USER:-kb}"; NPW="${NTFY_PASSWORD:-$(openssl rand -hex 12)}"; TOPIC="${NTFY_TOPIC:-kb}"

# --- Binary (robust, neueste Release) ---
if [ ! -x /usr/local/bin/ntfy ] && ! command -v ntfy >/dev/null; then
  V=$(curl -fsSL https://api.github.com/repos/binwiederhier/ntfy/releases/latest | jq -r .tag_name | sed 's/^v//')
  curl -fsSL "https://github.com/binwiederhier/ntfy/releases/download/v${V}/ntfy_${V}_linux_amd64.tar.gz" -o /tmp/ntfy.tgz
  tar -C /tmp -xzf /tmp/ntfy.tgz
  install -m0755 "/tmp/ntfy_${V}_linux_amd64/ntfy" /usr/local/bin/ntfy
  rm -rf /tmp/ntfy*
fi
NTFY_BIN="$(command -v ntfy || echo /usr/local/bin/ntfy)"

mkdir -p /var/lib/ntfy /etc/ntfy
cat > /etc/ntfy/server.yml <<CFG
base-url: "http://localhost:8080"
listen-http: "0.0.0.0:8080"
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
cache-file: "/var/lib/ntfy/cache.db"
CFG
export NTFY_CONFIG_FILE=/etc/ntfy/server.yml

# NTFY_USER/PW in .env sichern
grep -q '^export NTFY_USER='     "$ENVF" || echo "export NTFY_USER=\"$NUSER\"" >> "$ENVF"
grep -q '^export NTFY_PASSWORD=' "$ENVF" || echo "export NTFY_PASSWORD=\"$NPW\"" >> "$ENVF"

# --- systemd-Unit + Server starten (legt user.db an) ---
cat > /etc/systemd/system/ntfy.service <<UNIT
[Unit]
Description=ntfy
After=network.target
[Service]
ExecStart=$NTFY_BIN serve --config /etc/ntfy/server.yml
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now ntfy
# auf user.db warten (Server erstellt sie beim ersten Start) — User add geht erst danach
for _ in $(seq 1 15); do [ -f /var/lib/ntfy/user.db ] && break; sleep 1; done

# --- User + Access (Basic-Auth; kein Token nötig) ---
if ! "$NTFY_BIN" user list 2>/dev/null | grep -q "^user $NUSER"; then
  NTFY_PASSWORD="$NPW" "$NTFY_BIN" user add "$NUSER" || true
fi
"$NTFY_BIN" access "$NUSER" "$TOPIC" rw || true
systemctl restart ntfy   # ACL/User sicher übernehmen
sleep 2

echo ">> ntfy :8080  User=$NUSER  Topic=$TOPIC  (Basic-Auth)"
curl -sf -u "$NUSER:$NPW" -d "ntfy setup ok" "http://localhost:8080/$TOPIC" >/dev/null 2>&1 \
  && echo ">> Test-Push ✓" || echo ">> WARN: Test-Push fehlgeschlagen (Logs: journalctl -u ntfy)"
