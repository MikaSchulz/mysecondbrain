#!/usr/bin/env bash
# 40-whisper.sh — whisper.cpp bauen + DE-Modell laden. Schreibt WHISPER_BIN/MODEL in /opt/kb/.env.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "als root"; exit 1; }
ENVF=/opt/kb/.env
MODEL="${1:-small}"        # tiny|base|small|medium  (DE: small/medium empfohlen)
DIR=/opt/whisper.cpp

apt-get update -y
apt-get install -y build-essential cmake git ffmpeg

if [ ! -d "$DIR/.git" ]; then
  git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$DIR"
fi
cd "$DIR"
git pull --ff-only 2>/dev/null || true
# Neuere Versionen: cmake build -> build/bin/whisper-cli ; ältere: make -> ./main
if cmake -B build >/dev/null 2>&1 && cmake --build build -j --config Release >/dev/null 2>&1; then :; else make -j || true; fi
bash ./models/download-ggml-model.sh "$MODEL"

BIN=""
for c in "$DIR/build/bin/whisper-cli" "$DIR/build/bin/main" "$DIR/main"; do
  [ -x "$c" ] && { BIN="$c"; break; }
done
[ -z "$BIN" ] && { echo "FEHLER: whisper-Binary nicht gefunden"; exit 1; }
MODELF="$DIR/models/ggml-$MODEL.bin"

sed -i "s|^export WHISPER_BIN=.*|export WHISPER_BIN=\"$BIN\"|"     "$ENVF" 2>/dev/null || echo "export WHISPER_BIN=\"$BIN\"" >> "$ENVF"
sed -i "s|^export WHISPER_MODEL=.*|export WHISPER_MODEL=\"$MODELF\"|" "$ENVF" 2>/dev/null || echo "export WHISPER_MODEL=\"$MODELF\"" >> "$ENVF"

echo ">> whisper.cpp gebaut: $BIN"
echo ">> Modell: $MODELF"
echo ">> .env aktualisiert (WHISPER_BIN/MODEL). Test:"
echo "   $BIN -l de -m $MODELF -nt -f <16khz.wav>"
