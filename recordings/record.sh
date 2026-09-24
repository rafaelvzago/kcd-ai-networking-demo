#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=${1:-recordings/kcd-demo-explicada-curl.cast}
test ! -e "$output"
raw=$(mktemp /tmp/kcd-demo-recording-XXXXXX.cast)
DEMO_RECORD=1 asciinema rec --headless --return --overwrite \
  --output-format asciicast-v2 --window-size 120x40 \
  --title 'KCD Brasil: demo explicada, com pausas por etapa' \
  --command 'bash recordings/demo.sh' "$raw"
python3 - "$raw" "$output" <<'PY'
import json
import sys

with open(sys.argv[1]) as source, open(sys.argv[2], "x") as target:
    target.write(next(source))
    markers = 0
    for line in source:
        event = json.loads(line)
        target.write(line)
        if event[1] == "o" and "Espaço para continuar." in event[2]:
            target.write(json.dumps([event[0], "m", "Continuar"], ensure_ascii=False) + "\n")
            markers += 1
    assert markers == 19, f"Esperados 19 pontos de pausa; encontrados {markers}"
PY
printf 'Gravação pronta. Reproduza com:\nasciinema play --pause-on-markers %s\n' "$output"
