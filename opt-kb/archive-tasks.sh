#!/usr/bin/env bash
# archive-tasks.sh — .archive-tasks (vom LLM, unklare Fälle): Zeilen per @uid aus tasks.md
# nach archive/tasks-YYYY-MM.md verschieben. Kalender bleibt unangetastet (kein CalDAV-DELETE).
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
HANDOFF="$VAULT/.archive-tasks"; TASKS="$VAULT/tasks.md"
[ -s "$HANDOFF" ] || { echo "archive-tasks: nichts"; exit 0; }
ARCH="$VAULT/archive/tasks-$(date +%Y-%m).md"; mkdir -p "$(dirname "$ARCH")"; touch "$ARCH"
n=0
while IFS= read -r line; do
  [ -z "${line// }" ] && continue
  if [[ "$line" =~ @uid\(([^\)]+)\) ]]; then uid="${BASH_REMATCH[1]}"; else uid=$(echo "$line"|tr -d '[:space:]'); fi
  [ -z "$uid" ] && continue
  grep -F "@uid($uid)" "$TASKS" >> "$ARCH" 2>/dev/null || true
  sed -i "/@uid($uid)/d" "$TASKS"
  n=$((n+1))
done < "$HANDOFF"
: > "$HANDOFF"
echo "archive-tasks: $n verschoben"
