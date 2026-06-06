#!/usr/bin/env bash
# entrypoint.sh — First-Boot-Init (gleiche Config-Logik wie LXC, ohne systemd) -> supervisord.
set -euo pipefail
KB=/opt/kb; DATA=/data; VAULT="$DATA/vault"
export TZ="${TZ:-Europe/Berlin}"
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime 2>/dev/null || true

mkdir -p "$DATA"/{vault,radicale/collections,ntfy,syncthing,tailscale,cache}

# --- .env persistent in /data, von /opt/kb/.env verlinkt ---
[ -f "$DATA/.env" ] || cp "$KB/.env.template" "$DATA/.env"
set_env(){ local k="$1" v="$2" f="$DATA/.env" t; t=$(mktemp); grep -v "^export $k=" "$f" 2>/dev/null > "$t" || true; printf 'export %s=%q\n' "$k" "$v" >> "$t"; mv "$t" "$f"; }
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && { set_env CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE_CODE_OAUTH_TOKEN"; date +%F > "$KB/.token-installed"; }
set_env RADICALE_USER     "${RADICALE_USER:-kb}"
set_env RADICALE_PW       "${RADICALE_PW:-changeme}"
set_env RADICALE_URL      "http://localhost:5232"
set_env RADICALE_CALENDAR "${RADICALE_CALENDAR:-routine}"
set_env NTFY_URL          "http://localhost:8080"
set_env NTFY_TOPIC        "${NTFY_TOPIC:-kb}"
set_env NTFY_USER         "${NTFY_USER:-kb}"
set_env NTFY_PASSWORD     "${NTFY_PASSWORD:-changeme}"
set_env KB_MODEL          "${KB_MODEL:-haiku}"
set_env KB_MAX_TURNS      "${KB_MAX_TURNS:-30}"
set_env MONTH_BUDGET_USD  "${MONTH_BUDGET_USD:-18}"
set_env MIN_AGE           "${MIN_AGE:-1800}"
set_env COOLDOWN          "${COOLDOWN:-1800}"
set_env MAX_RUNS_DAY      "${MAX_RUNS_DAY:-10}"
set_env KB_HOME           "$KB"
set_env VAULT             "$VAULT"
[ -n "${WHISPER_BIN:-}" ]   && set_env WHISPER_BIN   "$WHISPER_BIN"
[ -n "${WHISPER_MODEL:-}" ] && set_env WHISPER_MODEL "$WHISPER_MODEL"
sed -i '/^export ANTHROPIC_API_KEY=/d' "$DATA/.env" || true
chmod 600 "$DATA/.env"
ln -sf "$DATA/.env" "$KB/.env"
rm -rf "$KB/.cache"; ln -sfn "$DATA/cache" "$KB/.cache"

# --- Vault seed (falls leer) ---
if [ ! -e "$VAULT/CLAUDE.md" ]; then
  cp -a "$KB/vault-seed/." "$VAULT/"
  ( cd "$VAULT" && git init -q && git add -A && git -c user.email=kb@local -c user.name=kb commit -qm seed ) || true
fi
ln -sfn "$VAULT" "$KB/vault"

# --- whisper-Binary autodetekt (falls im Image gebaut) ---
if [ -z "${WHISPER_BIN:-}" ]; then
  for c in /opt/whisper.cpp/build/bin/whisper-cli /opt/whisper.cpp/main; do
    [ -x "$c" ] && { set_env WHISPER_BIN "$c"; set_env WHISPER_MODEL "/opt/whisper.cpp/models/ggml-small.bin"; break; }
  done
fi

# --- Radicale config + htpasswd ---
source "$DATA/.env"
htpasswd -cbB "$DATA/radicale/users" "$RADICALE_USER" "$RADICALE_PW" >/dev/null 2>&1 || true
cat > "$DATA/radicale/config" <<CFG
[server]
hosts = 0.0.0.0:5232
[auth]
type = htpasswd
htpasswd_filename = /data/radicale/users
htpasswd_encryption = bcrypt
[storage]
filesystem_folder = /data/radicale/collections
CFG

# --- ntfy config + user/access (offline gegen user.db) ---
cat > "$DATA/ntfy/server.yml" <<CFG
base-url: "http://localhost:8080"
listen-http: "0.0.0.0:8080"
auth-file: "/data/ntfy/user.db"
auth-default-access: "deny-all"
cache-file: "/data/ntfy/cache.db"
attachment-cache-dir: "/data/ntfy/attachments"
CFG
export NTFY_CONFIG_FILE="$DATA/ntfy/server.yml"
# ntfy legt user.db erst beim Server-Start an -> kurz vorstarten, dann User/Access setzen, dann beenden.
ntfy serve --config "$DATA/ntfy/server.yml" >/dev/null 2>&1 &
NTFY_PID=$!
for _ in $(seq 1 15); do [ -f "$DATA/ntfy/user.db" ] && break; sleep 1; done
if ! ntfy user list 2>/dev/null | grep -q "^user $NTFY_USER"; then
  NTFY_PASSWORD="$NTFY_PASSWORD" ntfy user add "$NTFY_USER" >/dev/null 2>&1 || true
fi
ntfy access "$NTFY_USER" "$NTFY_TOPIC" rw >/dev/null 2>&1 || true
kill "$NTFY_PID" >/dev/null 2>&1 || true; wait "$NTFY_PID" 2>/dev/null || true

# --- cron (im Container) ---
cat > /etc/cron.d/kb <<'CRON'
*/10 * * * * root /opt/kb/run.sh >> /opt/kb/run.log 2>&1
5 4 * * *    root /opt/kb/rollover.sh >> /opt/kb/run.log 2>&1
10 4 * * *   root /opt/kb/expire.sh >> /opt/kb/run.log 2>&1
15 4 * * *   root /opt/kb/recurring.sh >> /opt/kb/run.log 2>&1
20 4 * * 1   root /opt/kb/vault-lint.sh >> /opt/kb/run.log 2>&1
30 3 * * *   root /opt/kb/backup.sh >> /opt/kb/run.log 2>&1
CRON
chmod 0644 /etc/cron.d/kb

echo "kb-entrypoint: init fertig. starte supervisord."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/kb.conf -n
