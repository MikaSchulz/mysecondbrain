#!/usr/bin/env bash
# cost-watch.sh — parst claude-Ausgabe (--output-format json) und führt Monats-$-Tally.
# Nutzt total_cost_usd falls vorhanden, sonst Schätzung aus usage-Tokens.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"
out="${1:-$KB/.last_out}"
[ -f "$out" ] || exit 0
month=$(date +%Y-%m); costf="$KB/.cost-$month"
cur=$(cat "$costf" 2>/dev/null || echo 0)

cost=$(jq -r 'if has("total_cost_usd") and (.total_cost_usd != null) then .total_cost_usd else empty end' "$out" 2>/dev/null || echo "")
if [ -z "$cost" ]; then
  tin=$(jq -r '(.usage.input_tokens // .usage.inputTokens // 0)'  "$out" 2>/dev/null || echo 0)
  tout=$(jq -r '(.usage.output_tokens // .usage.outputTokens // 0)' "$out" 2>/dev/null || echo 0)
  cost=$(awk -v i="$tin" -v o="$tout" -v pi="${PRICE_IN_PER_MTOK:-1.0}" -v po="${PRICE_OUT_PER_MTOK:-5.0}" \
    'BEGIN{printf "%.6f", i/1e6*pi + o/1e6*po}')
fi
[ -z "$cost" ] && cost=0
new=$(awk -v a="$cur" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')
echo "$new" > "$costf"
printf '%s cost: +$%s -> $%s (Monat %s)\n' "$(date -Is)" "$cost" "$new" "$month"

budget="${MONTH_BUDGET_USD:-18}"
if awk "BEGIN{exit !($new + 0 >= 0.8*($budget + 0))}"; then
  warn="$KB/.cost-warned-$month"
  if [ ! -f "$warn" ]; then
    /opt/kb/ntfy-send.sh "kb: Monats-Kosten \$$new (>=80% von \$$budget)"
    touch "$warn"
  fi
fi
