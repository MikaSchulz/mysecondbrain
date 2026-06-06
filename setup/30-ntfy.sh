#!/usr/bin/env bash
# 30-ntfy.sh — ntfy-Server + Auth + Token. Bind 0.0.0.0:8080 (LAN+Tailnet). Token wird in .env geschrieben.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
ENVF=/opt/kb/.env
source "$ENVF" 2>/dev/null || true
NUSER="${NTFY_USER:-kb}"; NPW="${NTFY_PASSWORD:-$(openssl rand -hex 12)}"; TOPIC="${NTFY_TOPIC:-kb}"

if ! command -v ntfy >/dev/null; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://archive.heckel.io/apt/pubkey.txt | gpg --dearmor -o /etc/apt/keyrings/ntfy.gpg
  echo "deb [signed-by=/etc/apt/keyrings/ntfy.gpg] https://archive.heckel.io/apt debian main" > /etc/apt/sources.list.d/ntfy.list
  apt-get update -y
  apt-get install -y ntfy
fi

mkdir -p /var/lib/ntfy /etc/ntfy
cat > /etc/ntfy/server.yml <<CFG
base-url: "http://localhost:8080"
listen-http: "0.0.0.0:8080"
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
CFG

systemctl enable --now ntfy
sleep 2

# User + ACL + Token (non-interaktiv via NTFY_PASSWORD)
if ! ntfy user list 2>/dev/null | grep -q "^user $NUSER"; then
  NTFY_PASSWORD="$NPW" ntfy user add "$NUSER"
fi
ntfy access "$NUSER" "$TOPIC" rw
TOKEN=$(ntfy token add "$NUSER" 2>/dev/null | grep -oE 'tk_[A-Za-z0-9]+' | head -1)
[ -z "$TOKEN" ] && { echo "WARN: Token-Erstellung fehlgeschlagen — manuell: ntfy token add $NUSER"; exit 1; }

# .env patchen
sed -i "s|^export NTFY_TOKEN=.*|export NTFY_TOKEN=\"$TOKEN\"|" "$ENVF" 2>/dev/null || echo "export NTFY_TOKEN=\"$TOKEN\"" >> "$ENVF"
grep -q '^export NTFY_USER=' "$ENVF" || echo "export NTFY_USER=\"$NUSER\"" >> "$ENVF"

echo ">> ntfy läuft auf :8080. User=$NUSER  Topic=$TOPIC"
echo ">> Token in $ENVF eingetragen."
echo ">> Geräte: ntfy-App -> Server http://kb.<tailnet>.ts.net:8080, Topic '$TOPIC', Token $TOKEN"
[ -n "${NTFY_PASSWORD:-}" ] || echo ">> ntfy-User-Passwort (für App-Login): $NPW   (notieren!)"
curl -sf -H "Authorization: Bearer $TOKEN" -d "ntfy setup ok" "http://localhost:8080/$TOPIC" >/dev/null && echo ">> Test-Push gesendet ✓" || echo ">> WARN: Test-Push fehlgeschlagen"
