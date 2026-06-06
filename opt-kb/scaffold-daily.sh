#!/usr/bin/env bash
# scaffold-daily.sh — legt bei neuem Tag wiki/journal/YYYY-MM-DD.md aus Template an (KEIN LLM).
set -euo pipefail
export TZ="${TZ:-Europe/Berlin}"
source /opt/kb/.env 2>/dev/null || true
VAULT="${VAULT:-/opt/kb/vault}"
d=$(date +%F)
f="$VAULT/wiki/journal/$d.md"
[ -f "$f" ] && exit 0
mkdir -p "$(dirname "$f")"
cat > "$f" <<EOF
---
title: "Journal $d"
tags: journal
created: $d
updated: $d
---

# $d
EOF
echo "scaffold-daily: $f angelegt"
