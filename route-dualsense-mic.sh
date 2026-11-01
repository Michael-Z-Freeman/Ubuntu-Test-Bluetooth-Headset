#!/usr/bin/env bash
# Forward the published DualSense capture port to the active HFP microphone uplink.
set -euo pipefail
PREVIOUS_ROUTE=""
if ! pw-link -o | grep -q '^alsa_input.DualSense_test_mic:'; then
  pw-cli create-node adapter '{ factory.name = api.alsa.pcm.source node.name = alsa_input.DualSense_test_mic node.description = "DualSense Microphone" media.class = Audio/Source api.alsa.path = "hw:Controller,0" audio.format = S16LE audio.rate = 48000 audio.channels = 2 audio.position = [ FL FR ] object.linger = true adapter.auto-port-config = { mode = dsp monitor = false position = preserve } }'
fi
while true; do
  PORTS=$(pw-link -o)
  SOURCE=$(printf '%s\n' "$PORTS" | grep -Ei '^alsa_input.*(DualSense|hw_Controller).*:capture_MONO$' | head -1 || true)
  if [[ -z $SOURCE ]]; then
    SOURCE=$(printf '%s\n' "$PORTS" | grep -Ei '^alsa_input.*(DualSense|hw_Controller).*:capture_(AUX0|FL)$' | head -1 || true)
  fi
  TARGET=$(pw-link -i | grep -E '^bluez_output\..*:input_(MONO|FL)$' | head -1 || true)
  if [[ -n $SOURCE && -n $TARGET ]]; then
    pw-link "$SOURCE" "$TARGET" 2>/dev/null || true
    if [[ $TARGET == *:input_FL ]]; then
      FR_TARGET=$(printf '%s' "$TARGET" | sed 's/:input_FL$/:input_FR/')
      FR_SOURCE="$SOURCE"
      if [[ $SOURCE == *:capture_FL ]]; then
        CANDIDATE=$(printf '%s' "$SOURCE" | sed 's/:capture_FL$/:capture_FR/')
        if printf '%s\n' "$PORTS" | grep -Fxq "$CANDIDATE"; then FR_SOURCE="$CANDIDATE"; fi
      fi
      pw-link "$FR_SOURCE" "$FR_TARGET" 2>/dev/null || true
    fi
    ROUTE="$SOURCE -> $TARGET"
    if [[ $ROUTE != "$PREVIOUS_ROUTE" ]]; then echo "$ROUTE"; fi
    PREVIOUS_ROUTE="$ROUTE"
  fi
  sleep 2
done
