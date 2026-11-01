#!/usr/bin/env bash
# Try existing signed btusb options; no driver installation or reboot.
set -euo pipefail
if [[ $EUID != 0 ]]; then
  echo "Run with sudo from Ubuntu's terminal."
  exit 1
fi
MODULE_PATH=$(modinfo -n btusb)
if [[ $MODULE_PATH != */kernel/drivers/bluetooth/btusb.ko* ]]; then
  echo "Expected the distribution btusb module; found $MODULE_PATH."
  echo "Review the installed driver before running this test."
  exit 1
fi
echo "Using distribution module: $MODULE_PATH"
echo "Signer: $(modinfo -F signer btusb)"
trap 'systemctl start bluetooth' EXIT
systemctl stop bluetooth
modprobe -r btusb
modprobe btusb force_scofix=1 enable_autosuspend=0
systemctl start bluetooth
trap - EXIT
echo "Applied temporary options:"
cat /sys/module/btusb/parameters/force_scofix
cat /sys/module/btusb/parameters/enable_autosuspend
echo "No reboot or signing-key enrollment was performed."
echo "The options last until btusb is unloaded or the computer restarts."
echo "To undo: stop bluetooth, unload btusb, load btusb normally, start bluetooth."
