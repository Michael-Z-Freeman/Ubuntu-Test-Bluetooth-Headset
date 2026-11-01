#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY' | pw-play --raw --format s16 --rate 16000 --channels 1 --channel-map MONO --target 0 --properties 'node.name=ubuntu-bt-test-tone' - >/tmp/ubuntu-bt-test-tone.log 2>&1 &
import math, signal, struct, sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
rate = 16000
block = b''.join(struct.pack('<h', round(3000*math.sin(2*math.pi*440*i/rate))) for i in range(rate))
while True:
    sys.stdout.buffer.write(block)
    sys.stdout.buffer.flush()
PY
TONE_PID=$!
trap 'kill "$TONE_PID" 2>/dev/null || true' EXIT
PREVIOUS_TARGET=""
while kill -0 "$TONE_PID" 2>/dev/null; do
  # Follow the active audio peer (Mac or iPad) rather than a fixed address.
  TARGET=$(pw-link -i | grep -E '^bluez_output\..*:input_(MONO|FL)$' | head -1 || true)
  if [[ -n $TARGET ]]; then
    pw-link 'ubuntu-bt-test-tone:output_MONO' "$TARGET" 2>/dev/null || true
    if [[ $TARGET != "$PREVIOUS_TARGET" ]]; then
      echo "440 Hz tone linked to $TARGET"
    fi
    if [[ $TARGET == *:input_FL ]]; then
      FR_TARGET=$(printf "%s" "$TARGET" | sed "s/:input_FL$/:input_FR/")
      pw-link "ubuntu-bt-test-tone:output_MONO" "$FR_TARGET" 2>/dev/null || true
    fi
  fi
  PREVIOUS_TARGET="$TARGET"
  sleep 2
done
wait "$TONE_PID"
