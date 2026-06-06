#!/usr/bin/env bash
# install.sh — richtet das kb-System auf dem NUC (LXC) ein. Idempotent. Als root ausführen.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
KB=/opt/kb; VAULT="$KB/vault"
[ "$(id -u)" = 0 ] || { echo "Bitte als root ausführen: sudo bash install.sh"; exit 1; }

echo "== kb install =="
mkdir -p "$KB" "$KB/.cache"

# --- Basis-Pakete + Claude CLI ---
if command -v apt-get >/dev/null; then
  apt-get update -y
  apt-get install -y git python3 python3-pip \
    cron curl jq tesseract-ocr tesseract-ocr-deu poppler-utils ffmpeg restic \
    inotify-tools nodejs npm ca-certificates tzdata 2>/dev/null || \
    echo "WARN: einige Pakete fehlten (später nachinstallieren)"
fi
if ! command -v claude >/dev/null; then
  npm install -g @anthropic-ai/claude-code 2>/dev/null && echo ">> Claude CLI installiert" \
    || echo ">> WARN: Claude CLI Install fehlgeschlagen — manuell: npm i -g @anthropic-ai/claude-code"
fi

# --- Skripte ---
install -m 0755 "$SRC"/opt-kb/*.sh "$KB"/
install -m 0755 "$SRC"/opt-kb/gen_ics.py "$KB"/
install -m 0755 "$SRC"/opt-kb/kb-ask "$SRC"/opt-kb/kb-ingest "$SRC"/opt-kb/kb-doctor "$KB"/
install -m 0644 "$SRC"/opt-kb/.env.template "$KB"/.env.template
# setup/, openwa/, systemd/ mitkopieren (configure.sh + setup-Skripte brauchen sie unter /opt/kb)
mkdir -p "$KB/setup" "$KB/openwa" "$KB/systemd"
install -m 0755 "$SRC"/setup/*.sh "$KB/setup/" 2>/dev/null || true
install -m 0644 "$SRC"/setup/README.md "$KB/setup/" 2>/dev/null || true
install -m 0644 "$SRC"/openwa/* "$KB/openwa/" 2>/dev/null || true
install -m 0644 "$SRC"/systemd/*.service "$KB/systemd/" 2>/dev/null || true
ln -sf "$KB/kb-ask"     /usr/local/bin/kb-ask
ln -sf "$KB/kb-ingest"  /usr/local/bin/kb-ingest
ln -sf "$KB/kb-doctor"  /usr/local/bin/kb-doctor
ln -sf "$KB/configure.sh" /usr/local/bin/kb-configure

# --- .env ---
if [ ! -f "$KB/.env" ]; then
  install -m 0600 "$SRC/opt-kb/.env.template" "$KB/.env"
  echo ">> $KB/.env angelegt — JETZT ausfüllen (Token via 'claude setup-token', Radicale/ntfy Creds)."
else
  echo ">> $KB/.env existiert, unverändert."
fi

# --- Vault seed ---
if [ ! -d "$VAULT/.git" ]; then
  mkdir -p "$VAULT"
  cp -a "$SRC"/vault-seed/. "$VAULT"/
  ( cd "$VAULT" && git init -q && git add -A && git commit -qm "seed" ) || true
  echo ">> Vault geseedet: $VAULT"
else
  echo ">> Vault existiert ($VAULT), seed übersprungen."
fi

# --- Cron (ersetzt alle /opt/kb-Zeilen idempotent) ---
TMPC="$(mktemp)"
crontab -l 2>/dev/null | grep -v '/opt/kb/' > "$TMPC" || true
cat >> "$TMPC" <<'CRON'
*/10 * * * * /opt/kb/run.sh        >> /opt/kb/run.log 2>&1
*/15 * * * * /opt/kb/health.sh     >> /opt/kb/run.log 2>&1
5 4 * * *    /opt/kb/rollover.sh    >> /opt/kb/run.log 2>&1
10 4 * * *   /opt/kb/expire.sh      >> /opt/kb/run.log 2>&1
15 4 * * *   /opt/kb/recurring.sh   >> /opt/kb/run.log 2>&1
20 4 * * 1   /opt/kb/vault-lint.sh  >> /opt/kb/run.log 2>&1
30 3 * * *   /opt/kb/backup.sh      >> /opt/kb/run.log 2>&1
CRON
crontab "$TMPC"; rm -f "$TMPC"
echo ">> Crontab installiert (run.sh */10 + Hygiene-Crons)."

# --- systemd watcher ---
if command -v systemctl >/dev/null; then
  install -m 0644 "$SRC/systemd/kb-watch.service" /etc/systemd/system/kb-watch.service
  systemctl daemon-reload
  systemctl enable --now kb-watch.service 2>/dev/null || echo "   (kb-watch erst nach .env-Setup starten: systemctl restart kb-watch)"
  echo ">> systemd kb-watch.service installiert."
fi

cat <<EOF

== Fertig. JETZT zentral konfigurieren ==
   sudo kb-configure        # Wizard: .env, Claude-Token, Tailscale, Dienste, WhatsApp
   kb-doctor                # Status: was läuft, was fehlt

Danach:  DRY_RUN=1 $KB/run.sh   (simuliert)   →   $KB/run.sh   (echt)
Details/Checkliste:  $SRC/CONFIG.md
EOF
