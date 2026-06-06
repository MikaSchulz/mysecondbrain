#!/usr/bin/env bash
# install-lxc.sh — auf dem PROXMOX-HOST ausführen (root). Erstellt einen kb-LXC und provisioniert
# alles out-of-the-box. Paar Parameter werden abgefragt (oder via ENV vorgeben für unattended).
#
#   bash proxmox/install-lxc.sh
#   CTID=210 RADICALE_PW=... TS_AUTHKEY=tskey-... CLAUDE_CODE_OAUTH_TOKEN=... NONINTERACTIVE=1 bash proxmox/install-lxc.sh
set -euo pipefail
command -v pct >/dev/null || { echo "Kein 'pct' gefunden — dieses Skript läuft auf dem Proxmox-HOST."; exit 1; }
[ "$(id -u)" = 0 ] || { echo "root nötig"; exit 1; }
# Repo-Quelle: bei lokalem Checkout wird der genutzt, sonst von GitHub geladen (Community-curl|bash).
KB_REPO="${KB_REPO:-MikaSchulz/mysecondbrain}"
KB_BRANCH="${KB_BRANCH:-main}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd || echo /nonexistent)"
NI="${NONINTERACTIVE:-0}"

# Prompts aus /dev/tty lesen (funktioniert auch bei  bash -c "$(curl ...)" ).
ask(){ local p="$1" d="${2:-}" r; [ "$NI" = 1 ] && { echo "$d"; return; }; read -rp "$p${d:+ [$d]}: " r </dev/tty || r=""; echo "${r:-$d}"; }
asksecret(){ local p="$1" d="${2:-}" r; [ "$NI" = 1 ] && { echo "$d"; return; }; read -rsp "$p: " r </dev/tty || r=""; echo >&2; echo "${r:-$d}"; }

echo "==== kb LXC Installer (Proxmox) ===="
# --- Container-Parameter ---
CTID="$(ask 'CTID' "${CTID:-$(pvesh get /cluster/nextid 2>/dev/null || echo 200)}")"
CTHOST="$(ask 'Hostname' "${CTHOST:-kb}")"
CORES="$(ask 'Cores' "${CORES:-2}")"
RAM="$(ask 'RAM (MB)' "${RAM:-4096}")"
DISK="$(ask 'Disk (GB)' "${DISK:-20}")"
STORAGE="$(ask 'Storage (rootfs)' "${STORAGE:-local-lvm}")"
BRIDGE="$(ask 'Netzwerk-Bridge' "${BRIDGE:-vmbr0}")"
TMPL_STORE="$(ask 'Template-Storage' "${TMPL_STORE:-local}")"
TZ_VAL="$(ask 'Timezone' "${TZ:-Europe/Berlin}")"

# --- App-Parameter ---
echo "--- App-Konfiguration (leer = später via 'kb-configure' im Container) ---"
CLAUDE_TOKEN="$(asksecret 'Claude OAuth-Token (claude setup-token)' "${CLAUDE_CODE_OAUTH_TOKEN:-}")"
TS_KEY="$(asksecret 'Tailscale Auth-Key (tskey-...)' "${TS_AUTHKEY:-}")"
RAD_PW="$(asksecret 'Radicale-Passwort' "${RADICALE_PW:-$(openssl rand -hex 8)}")"
NTFY_PW="$(asksecret 'ntfy-Passwort' "${NTFY_PASSWORD:-$(openssl rand -hex 8)}")"
NTFY_TOP="$(ask 'ntfy-Topic' "${NTFY_TOPIC:-kb}")"
WHISPER="$(ask 'whisper bauen (Voice)? yes/no' "${WITH_WHISPER:-no}")"

# --- Template sicherstellen ---
echo ">> Template prüfen ..."
pveam update >/dev/null 2>&1 || true
TPL="$(pveam available --section system 2>/dev/null | awk '/debian-12-standard/{print $2}' | sort -V | tail -1)"
[ -z "$TPL" ] && { echo "Kein debian-12-standard Template verfügbar (pveam available prüfen)."; exit 1; }
pveam list "$TMPL_STORE" 2>/dev/null | grep -q "$TPL" || pveam download "$TMPL_STORE" "$TPL"
TPL_REF="$TMPL_STORE:vztmpl/$TPL"

# --- LXC erstellen ---
echo ">> Erstelle LXC $CTID ($CTHOST) ..."
pct create "$CTID" "$TPL_REF" \
  -hostname "$CTHOST" -cores "$CORES" -memory "$RAM" -swap 512 \
  -rootfs "$STORAGE:$DISK" -net0 "name=eth0,bridge=$BRIDGE,ip=dhcp" \
  -features nesting=1 -unprivileged 1 -onboot 1

CONF="/etc/pve/lxc/$CTID.conf"
grep -q 'dev/net/tun' "$CONF" || cat >> "$CONF" <<'TUN'
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
TUN

pct start "$CTID"
echo ">> Warte auf Netzwerk ..."
for _ in $(seq 1 30); do pct exec "$CTID" -- getent hosts deb.debian.org >/dev/null 2>&1 && break; sleep 2; done

# --- Timezone ---
pct exec "$CTID" -- bash -c "ln -sf /usr/share/zoneinfo/$TZ_VAL /etc/localtime; echo $TZ_VAL > /etc/timezone" || true

# --- Tools im Container für Download ---
pct exec "$CTID" -- bash -c 'apt-get update -y >/dev/null 2>&1; apt-get install -y curl ca-certificates tar >/dev/null 2>&1' || true
pct exec "$CTID" -- mkdir -p /root/mysecondbrain

# --- Repo in den Container: lokaler Checkout (dev) ODER GitHub-Download (Community) ---
if [ -f "$REPO_DIR/install.sh" ] && [ "${KB_FORCE_REMOTE:-0}" != 1 ]; then
  echo ">> Lokalen Checkout verwenden ($REPO_DIR)"
  TGZ="$(mktemp --suffix=.tgz)"
  tar czf "$TGZ" -C "$REPO_DIR" --exclude=.git .
  pct push "$CTID" "$TGZ" /root/mysecondbrain.tgz
  pct exec "$CTID" -- tar xzf /root/mysecondbrain.tgz -C /root/mysecondbrain
  rm -f "$TGZ"
else
  echo ">> Lade Repo von GitHub ($KB_REPO@$KB_BRANCH) ..."
  pct exec "$CTID" -- bash -c "curl -fsSL https://github.com/$KB_REPO/archive/refs/heads/$KB_BRANCH.tar.gz | tar xz --strip-components=1 -C /root/mysecondbrain" \
    || { echo 'FEHLER: Repo-Download fehlgeschlagen (Repo public? Branch korrekt?)'; exit 1; }
fi

# --- Params-Datei im Container (chmod 600) ---
pct exec "$CTID" -- bash -c 'cat > /root/kb-params.env' <<EOF
export CLAUDE_CODE_OAUTH_TOKEN=$(printf '%q' "$CLAUDE_TOKEN")
export TS_AUTHKEY=$(printf '%q' "$TS_KEY")
export RADICALE_PW=$(printf '%q' "$RAD_PW")
export NTFY_PASSWORD=$(printf '%q' "$NTFY_PW")
export NTFY_TOPIC=$(printf '%q' "$NTFY_TOP")
export WITH_WHISPER=$(printf '%q' "$WHISPER")
export TZ=$(printf '%q' "$TZ_VAL")
EOF
pct exec "$CTID" -- chmod 600 /root/kb-params.env

# --- Provisionieren ---
echo ">> install.sh ..."
pct exec "$CTID" -- bash -c 'cd /root/mysecondbrain && bash install.sh'
echo ">> configure unattended ..."
pct exec "$CTID" -- bash -c 'set -a; source /root/kb-params.env; set +a; /opt/kb/configure.sh unattended'

echo
echo "==== Fertig: kb-LXC $CTID ($CTHOST) ===="
pct exec "$CTID" -- kb-doctor || true
cat <<EOF

Zugang:        pct enter $CTID
Nachkonfig:    pct exec $CTID -- kb-configure        (z.B. Claude-Token/Tailscale falls leer gelassen)
WhatsApp:      pct exec $CTID -- bash /opt/kb/setup/60-openwa.sh   (optional, QR scannen)
Radicale-PW:   $RAD_PW
ntfy-PW:       $NTFY_PW
Geräte erreichen Dienste über den Tailnet-Namen (kb.<tailnet>.ts.net): CalDAV :5232, ntfy :8080, Syncthing :8384.
EOF
