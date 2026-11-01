#!/usr/bin/env bash
# Route the active Bluetooth headset's headphone audio to the Creative SXFI.
set -euo pipefail
amixer -c AMP sset PCM 80% unmute >/dev/null
if ! pw-link -i | grep -q '^alsa_output.SXFI_test_headphones:'; then
  pw-cli create-node adapter '{ factory.name = api.alsa.pcm.sink node.name = alsa_output.SXFI_test_headphones node.description = "Creative SXFI Headphones" media.class = Audio/Sink api.alsa.path = "hw:AMP,0" audio.format = S16LE audio.rate = 48000 audio.channels = 2 audio.position = [ FL FR ] object.linger = true adapter.auto-port-config = { mode = dsp monitor = true position = preserve } }'
fi
SINK_ID=$(pw-dump | python3 -c 'import json,sys; print(next(o["id"] for o in json.load(sys.stdin) if o.get("info",{}).get("props",{}).get("node.name")=="alsa_output.SXFI_test_headphones"))')
wpctl set-default "$SINK_ID"
wpctl set-mute "$SINK_ID" 0
wpctl set-volume "$SINK_ID" 0.80
PREVIOUS_ROUTE=""
while true; do
  SOURCE=$(pw-link -o | grep -E '^bluez_input\..*:output_(FL|MONO)$' | head -1 || true)
  if [[ -n $SOURCE ]]; then
    pw-link "$SOURCE" 'alsa_output.SXFI_test_headphones:playback_FL' 2>/dev/null || true
    FR_SOURCE="$SOURCE"
    if [[ $SOURCE == *:output_FL ]]; then
      CANDIDATE=$(printf '%s' "$SOURCE" | sed 's/:output_FL$/:output_FR/')
      if pw-link -o | grep -Fxq "$CANDIDATE"; then FR_SOURCE="$CANDIDATE"; fi
    fi
    pw-link "$FR_SOURCE" 'alsa_output.SXFI_test_headphones:playback_FR' 2>/dev/null || true
    # Remove only this peer's obsolete dummy-output routes.
    pw-link -d "$SOURCE" 'auto_null:playback_FL' 2>/dev/null || true
    pw-link -d "$FR_SOURCE" 'auto_null:playback_FR' 2>/dev/null || true
    if [[ $SOURCE != "$PREVIOUS_ROUTE" ]]; then
      echo "$SOURCE -> Creative SXFI Headphones (unmuted, 80%)"
      PREVIOUS_ROUTE="$SOURCE"
    fi
  fi
  sleep 2
done
