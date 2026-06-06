#!/usr/bin/env bash
# tailscale-run.sh — tailscaled + (optional) up via TS_AUTHKEY. Ohne TUN: No-Op (kein Crash-Loop).
set -uo pipefail
if [ ! -e /dev/net/tun ]; then
  echo "tailscale-run: kein /dev/net/tun -> Tailscale deaktiviert (compose: cap_add NET_ADMIN + devices /dev/net/tun)."
  exec sleep infinity
fi
mkdir -p /var/run/tailscale /data/tailscale
tailscaled --state=/data/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
TPID=$!
sleep 3
if [ -n "${TS_AUTHKEY:-}" ]; then
  tailscale --socket=/var/run/tailscale/tailscaled.sock up \
    --authkey="$TS_AUTHKEY" --hostname="${TS_HOSTNAME:-kb}" --accept-dns=true || echo "tailscale up Fehler"
else
  echo "tailscale-run: kein TS_AUTHKEY -> tailscaled läuft, 'tailscale up' manuell oder ENV setzen."
fi
wait "$TPID"
