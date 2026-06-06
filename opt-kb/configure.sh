#!/usr/bin/env bash
# configure.sh — ZENTRALER Einrichtungs-Wizard. Alle Logins/Configs an einem Ort.
# Aufruf:  sudo /opt/kb/configure.sh        (Menü)   |   sudo /opt/kb/configure.sh all
set -uo pipefail
KB=/opt/kb; ENVF="$KB/.env"; SETUP="$KB/setup"; VAULT="$KB/vault"
[ -f "$ENVF" ] || cp "$KB/.env.template" "$ENVF" 2>/dev/null || true
chmod 600 "$ENVF" 2>/dev/null || true

c_grn(){ printf '\033[32m%s\033[0m\n' "$1"; }
c_red(){ printf '\033[31m%s\033[0m\n' "$1"; }
need_root(){ [ "$(id -u)" = 0 ] || { c_red "Schritt braucht root (sudo $0)"; return 1; }; }
set_env(){ local k="$1" v="$2" tmp; tmp=$(mktemp)
  grep -v "^export $k=" "$ENVF" 2>/dev/null > "$tmp" || true
  printf 'export %s=%q\n' "$k" "$v" >> "$tmp"
  mv "$tmp" "$ENVF"; chmod 600 "$ENVF"; }
ask(){ local p="$1" d="${2:-}" r; read -rp "$p${d:+ [$d]}: " r; echo "${r:-$d}"; }
asksecret(){ local p="$1" r; read -rsp "$p: " r; echo >&2; echo "$r"; }

step_env(){
  echo "== 1) .env Grunddaten =="
  source "$ENVF" 2>/dev/null || true
  set_env RADICALE_USER     "$(ask 'Radicale-User' "${RADICALE_USER:-kb}")"
  local rp; rp="$(asksecret 'Radicale-Passwort (leer = behalten)')"; [ -n "$rp" ] && set_env RADICALE_PW "$rp"
  set_env NTFY_TOPIC        "$(ask 'ntfy-Topic' "${NTFY_TOPIC:-kb}")"
  set_env MONTH_BUDGET_USD  "$(ask 'Monats-Budget USD' "${MONTH_BUDGET_USD:-18}")"
  set_env MIN_AGE           "$(ask 'Sammelfenster Sek (1800=30min)' "${MIN_AGE:-1800}")"
  set_env KB_MODEL          "$(ask 'Modell (haiku/sonnet)' "${KB_MODEL:-haiku}")"
  chmod 600 "$ENVF"; c_grn "ok — .env gespeichert"
}

step_claude(){
  echo "== 2) Claude Abo-Token (KEIN API-Key) =="
  echo "Startet 'claude setup-token' (Abo-OAuth). URL öffnen/anmelden, dann Token kopieren."
  command -v claude >/dev/null || { c_red "claude CLI nicht installiert"; return 1; }
  claude setup-token || true
  local t; t="$(asksecret 'Token einfügen (leer = überspringen)')"
  if [ -n "$t" ]; then
    set_env CLAUDE_CODE_OAUTH_TOKEN "$t"; date +%F > "$KB/.token-installed"
    sed -i '/^export ANTHROPIC_API_KEY=/d' "$ENVF" 2>/dev/null || true
    c_grn "ok — Token gespeichert, ANTHROPIC_API_KEY entfernt"
  else c_red "übersprungen"; fi
}

step_tailscale(){ echo "== 3) Tailscale-Login =="; need_root || return; bash "$SETUP/10-tailscale.sh"; }

step_services(){
  echo "== 4) Dienste (Radicale/ntfy/whisper/Syncthing) =="; need_root || return
  bash "$SETUP/20-radicale.sh" || c_red "radicale-Setup-Fehler"
  bash "$SETUP/30-ntfy.sh"     || c_red "ntfy-Setup-Fehler"
  read -rp "whisper.cpp jetzt bauen (dauert einige Min)? [y/N] " a
  [ "${a,,}" = y ] && bash "$SETUP/40-whisper.sh" small
  bash "$SETUP/50-syncthing.sh" || c_red "syncthing-Setup-Fehler"
}

step_whatsapp(){
  echo "== 5) WhatsApp (OpenWA) — experimentell, ToS-Risiko =="; need_root || return
  [ -f "$SETUP/60-openwa.sh" ] || { c_red "setup/60-openwa.sh fehlt"; return 1; }
  bash "$SETUP/60-openwa.sh"
}

step_doctor(){ echo "== 6) Status =="; "$KB/kb-doctor"; }

run_all(){ step_env; step_claude; step_tailscale; step_services; step_doctor;
  echo; echo "WhatsApp separat: $0  -> Menüpunkt 5 (optional)."; }

# Vollautomatisch aus ENV (für Proxmox-Installer). Keine Prompts.
# Erwartet: CLAUDE_CODE_OAUTH_TOKEN, RADICALE_USER/PW, NTFY_TOPIC/USER/PASSWORD,
#           optional TS_AUTHKEY, WITH_WHISPER, WHISPER_MODEL_SIZE, MONTH_BUDGET_USD, MIN_AGE, KB_MODEL.
unattended(){
  need_root || exit 1
  echo "== unattended configure =="
  [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && { set_env CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE_CODE_OAUTH_TOKEN"; date +%F > "$KB/.token-installed"; }
  set_env RADICALE_USER     "${RADICALE_USER:-kb}"
  set_env RADICALE_PW       "${RADICALE_PW:?RADICALE_PW erforderlich}"
  set_env NTFY_TOPIC        "${NTFY_TOPIC:-kb}"
  set_env NTFY_USER         "${NTFY_USER:-kb}"
  set_env MONTH_BUDGET_USD  "${MONTH_BUDGET_USD:-18}"
  set_env MIN_AGE           "${MIN_AGE:-1800}"
  set_env KB_MODEL          "${KB_MODEL:-haiku}"
  sed -i '/^export ANTHROPIC_API_KEY=/d' "$ENVF" 2>/dev/null || true
  chmod 600 "$ENVF"

  TS_AUTHKEY="${TS_AUTHKEY:-}" bash "$SETUP/10-tailscale.sh" || echo "WARN tailscale (ggf. später: tailscale up)"
  NTFY_PASSWORD="${NTFY_PASSWORD:-}" bash "$SETUP/20-radicale.sh"
  NTFY_PASSWORD="${NTFY_PASSWORD:-}" bash "$SETUP/30-ntfy.sh"
  if [ "${WITH_WHISPER:-no}" = yes ]; then bash "$SETUP/40-whisper.sh" "${WHISPER_MODEL_SIZE:-small}"; fi
  bash "$SETUP/50-syncthing.sh" || true
  "$KB/kb-doctor" || true
  echo "== unattended fertig =="
}

case "${1:-}" in
  all)        run_all; exit 0;;
  unattended) unattended; exit 0;;
esac

while true; do
  echo
  echo "==== kb configure ===="
  echo " 1) .env Grunddaten (Radicale-PW, ntfy-Topic, Budget, Modell)"
  echo " 2) Claude Abo-Token  (claude setup-token)"
  echo " 3) Tailscale-Login   (tailscale up)"
  echo " 4) Dienste install   (radicale/ntfy/whisper/syncthing)"
  echo " 5) WhatsApp-Login    (OpenWA, experimentell)"
  echo " 6) Status / Doctor"
  echo " 7) Alles 1-4 + 6"
  echo " 0) Ende"
  read -rp "Auswahl: " ch
  case "$ch" in
    1) step_env;; 2) step_claude;; 3) step_tailscale;; 4) step_services;;
    5) step_whatsapp;; 6) step_doctor;; 7) run_all;; 0|q) exit 0;;
    *) c_red "ungültig";;
  esac
done
