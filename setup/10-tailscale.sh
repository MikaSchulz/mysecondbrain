#!/usr/bin/env bash
# 10-tailscale.sh — Tailscale als EIGENER Node im kb-LXC. Als root.
# Voraussetzung (auf Proxmox-HOST, vor LXC-Start): /dev/net/tun durchgereicht:
#   lxc.cgroup2.devices.allow: c 10:200 rwm
#   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root ausführen"; exit 1; }

if [ ! -e /dev/net/tun ]; then
  echo "FEHLER: /dev/net/tun fehlt im LXC. Auf dem Proxmox-Host durchreichen (siehe Header) und LXC neustarten."
  echo "Alternative (ohne TUN): tailscale up --tun=userspace-networking  — dann aber Service-Exposure prüfen."
  exit 1
fi

if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

if [ -n "${TS_AUTHKEY:-}" ]; then
  echo ">> Non-interaktiver Login via TS_AUTHKEY"
  tailscale up --authkey="$TS_AUTHKEY" --hostname=kb --accept-dns=true
else
  echo ">> Jetzt anmelden (öffnet Auth-URL):"
  tailscale up --hostname=kb --accept-dns=true
fi

echo
tailscale status || true
echo ">> MagicDNS-Name vermutlich: kb.<tailnet>.ts.net  (für CalDAV/ntfy auf den Geräten)."
echo ">> tailscale ip -4   ->  $(tailscale ip -4 2>/dev/null || echo '(noch nicht verbunden)')"
