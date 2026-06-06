#!/usr/bin/env bash
# move-processed.sh — tmp/ -> processed/ (final). Nur was der LLM bestätigt (nach tmp/ gezogen) hat.
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
TMP="$VAULT/tmp"; PROC="$VAULT/processed"; mkdir -p "$PROC"
moved=0
while IFS= read -r f; do
  [ -e "$f" ] || continue
  bn=$(basename "$f"); dest="$PROC/$bn"
  [ -e "$dest" ] && dest="$PROC/$(date +%s)-$bn"
  mv "$f" "$dest"; moved=$((moved+1))
done < <(find "$TMP" -type f ! -name '.gitkeep' 2>/dev/null)
# leere Unterordner in tmp aufräumen
find "$TMP" -mindepth 1 -type d -empty -delete 2>/dev/null || true
echo "move-processed: $moved Datei(en)"
