#!/usr/bin/env bash
# guard.sh — entscheidet ob run.sh den LLM-Pfad betreten darf.
# return 0 = erlaubt (proceed), return 1 = blockiert (run.sh -> exit 0).
# Gates: Monats-Budget + Tages-Cap (HART, auch urgent) | Cooldown + 30-min-Sammelfenster (urgent bypasst).
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"; VAULT="${VAULT:-/opt/kb/vault}"
now=$(date +%s)

notify(){ /opt/kb/ntfy-send.sh "$1"; }

real_files(){ find "$1" -type f ! -name '.gitkeep' 2>/dev/null; }

urgent=0
[ -n "$(real_files "$VAULT/raw/urgent")" ] && urgent=1

# --- HARTE Caps (gelten immer) ---
# Monats-Budget
month=$(date +%Y-%m); spent=$(cat "$KB/.cost-$month" 2>/dev/null || echo 0)
if awk "BEGIN{exit !($spent + 0 >= ${MONTH_BUDGET_USD:-18} + 0)}"; then
  warn="$KB/.budget-warned-$(date +%F)"
  [ -f "$warn" ] || { notify "kb: Monats-Budget \$$spent erreicht (>= \$${MONTH_BUDGET_USD:-18}) — Automation pausiert."; touch "$warn"; }
  exit 1
fi
# Tages-Cap
runs=$(wc -l < "$KB/.runs-$(date +%F)" 2>/dev/null || echo 0)
[ "$runs" -ge "${MAX_RUNS_DAY:-10}" ] && exit 1

# --- Timing (urgent bypasst) ---
if [ "$urgent" -eq 1 ]; then exit 0; fi

# Cooldown
last=$(cat "$KB/.last_run" 2>/dev/null || echo 0)
[ $(( now - last )) -lt "${COOLDOWN:-1800}" ] && exit 1

# Sammelfenster: ältestes raw-Item (ohne urgent) muss >= MIN_AGE alt sein
oldest=$(find "$VAULT/raw" -path "$VAULT/raw/urgent" -prune -o -type f ! -name '.gitkeep' -printf '%T@\n' 2>/dev/null | sort -n | head -1)
if [ -n "$oldest" ]; then
  oi=${oldest%.*}
  [ $(( now - oi )) -lt "${MIN_AGE:-1800}" ] && exit 1   # noch am Sammeln
fi
exit 0
