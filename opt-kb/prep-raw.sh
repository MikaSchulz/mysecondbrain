#!/usr/bin/env bash
# prep-raw.sh — deterministische Vorverarbeitung von raw/ (KEIN LLM):
#   - Syncthing-Teildateien + instabile (frisch geschriebene) Dateien überspringen
#   - Dedup per SHA (.seen)
#   - PDF  -> pdftotext -> raw/pdf/<name>.md (+ Original nach processed/pdf/)
#   - Audio-> ffmpeg+whisper.cpp -> raw/audio/<name>.md (+ Original nach processed/audio/)  [Phase 2]
#   - Text/Notes/Chats -> Frontmatter sicherstellen
#   - Input-Cap (MAX_ITEMS_PER_RUN)
set -euo pipefail
source /opt/kb/.env 2>/dev/null || true
KB="${KB_HOME:-/opt/kb}"; VAULT="${VAULT:-/opt/kb/vault}"
RAW="$VAULT/raw"; PROC="$VAULT/processed"
SEEN="$KB/.seen"; : > /dev/null; touch "$SEEN"
MAX="${MAX_ITEMS_PER_RUN:-20}"; STABLE="${PREP_STABLE_SEC:-10}"
DRY="${DRY_RUN:-0}"; now=$(date +%s); count=0

log(){ printf '%s prep: %s\n' "$(date -Is)" "$1"; }
is_skip(){ case "$(basename "$1")" in .gitkeep|.*.tmp|*~syncthing~*|*.syncthing.*|*.part) return 0;; esac; return 1; }
stable(){ local m; m=$(stat -c %Y "$1" 2>/dev/null || echo 0); [ $(( now - m )) -ge "$STABLE" ]; }
seen(){ grep -qxF "$1" "$SEEN"; }
mark(){ echo "$1" >> "$SEEN"; }
fm_date(){ date -Is -d @"$(stat -c %Y "$1")"; }

process_one(){
  local f="$1"
  is_skip "$f" && return 0
  stable "$f" || { log "skip instabil: $f"; return 0; }
  local h; h=$(sha256sum "$f" | cut -d' ' -f1)
  if seen "$h"; then
    log "dup entfernt: $f"; [ "$DRY" = 1 ] || rm -f "$f"; return 0
  fi
  count=$((count+1)); [ "$count" -gt "$MAX" ] && return 0
  local base; base=$(basename "$f")
  case "$f" in
    "$RAW"/pdf/*.pdf|"$RAW"/pdf/*.PDF)
      [ "$DRY" = 1 ] && { log "would pdf->md: $f"; return 0; }
      local stem="${base%.*}" out="$RAW/pdf/${stem}.md"; mkdir -p "$PROC/pdf"
      { printf -- '---\ntitle: "%s"\ntype: pdf\nsources: processed/pdf/%s\ndate: %s\n---\n\n' \
          "$stem" "$base" "$(fm_date "$f")"
        pdftotext -layout "$f" - 2>/dev/null || echo "(pdftotext: kein Text — evtl. Scan, OCR nötig)"
      } > "$out"
      mv "$f" "$PROC/pdf/"; mark "$h"; log "pdf->md: $out" ;;
    "$RAW"/audio/*.md) : ;;   # bereits transkribiert
    "$RAW"/audio/*)
      if [ ! -x "${WHISPER_BIN:-/nonexistent}" ]; then
        log "WARN whisper fehlt -> Audio bleibt liegen (Phase 2): $f"; return 0; fi
      [ "$DRY" = 1 ] && { log "would transcribe: $f"; return 0; }
      local stem="${base%.*}" wav="/tmp/kb-$$-$stem.wav" out="$RAW/audio/${stem}.md"; mkdir -p "$PROC/audio"
      ffmpeg -y -i "$f" -ar 16000 -ac 1 "$wav" >/dev/null 2>&1 || { log "ffmpeg-Fehler: $f"; return 0; }
      { printf -- '---\ntitle: "%s"\ntype: voice\nsources: processed/audio/%s\ndate: %s\n---\n\n' \
          "$stem" "$base" "$(fm_date "$f")"
        "$WHISPER_BIN" -l "${WHISPER_LANG:-de}" -m "${WHISPER_MODEL:?}" -nt -f "$wav" 2>/dev/null || echo "(Transkription leer)"
      } > "$out"
      rm -f "$wav"; mv "$f" "$PROC/audio/"; mark "$h"; log "audio->md: $out" ;;
    *)
      [ "$DRY" = 1 ] && { log "would normalize: $f"; return 0; }
      if ! head -1 "$f" | grep -q '^---'; then
        local t; t=$(mktemp)
        { printf -- '---\ntitle: "%s"\ntype: note\nsources: %s\ndate: %s\n---\n\n' \
            "${base%.*}" "$(realpath --relative-to="$VAULT" "$f")" "$(fm_date "$f")"
          cat "$f"; } > "$t"
        mv "$t" "$f"
      fi
      mark "$h"; log "normalized: $f" ;;
  esac
}

while IFS= read -r f; do
  [ "$count" -gt "$MAX" ] && { log "Input-Cap $MAX erreicht, Rest wartet"; break; }
  process_one "$f"
done < <(find "$RAW" -type f ! -name '.gitkeep' | sort)
exit 0
