#!/usr/bin/env bash
# archive-stale.sh — .stale -> wiki-Seiten nach archive/stale/ verschieben (git mv). Dann .stale leeren.
# Zeilenformat: "wiki/pfad.md [superseded-by wiki/neu.md]"
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
STALE="$VAULT/.stale"; DST="$VAULT/archive/stale"
[ -s "$STALE" ] || { echo "archive-stale: nichts"; exit 0; }
mkdir -p "$DST"
n=0
while IFS= read -r line; do
  [ -z "${line// }" ] && continue
  src=$(awk '{print $1}' <<<"$line")
  case "$src" in wiki/*) : ;; *) continue ;; esac        # nur wiki/-Pfade
  [ -f "$VAULT/$src" ] || continue
  bn=$(basename "$src"); out="archive/stale/$bn"
  [ -e "$VAULT/$out" ] && out="archive/stale/$(date +%s)-$bn"
  if git -C "$VAULT" mv "$src" "$out" 2>/dev/null; then :; else mv "$VAULT/$src" "$VAULT/$out"; fi
  n=$((n+1)); echo "archive-stale: $src -> $out"
done < "$STALE"
: > "$STALE"
echo "archive-stale: $n verschoben"
