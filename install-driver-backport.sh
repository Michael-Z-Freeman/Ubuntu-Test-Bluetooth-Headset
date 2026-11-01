#!/usr/bin/env bash
# Add the missing Realtek setup quirk for the IMC 13d3:3556 adapter.
set -euo pipefail

if [[ $EUID != 0 ]]; then
  echo "Run with sudo from the Ubuntu terminal."
  exit 1
fi
KERNEL_RELEASE=$(uname -r)
if [[ $KERNEL_RELEASE != 7.0.* ]]; then
  echo "This backport is prepared for Ubuntu kernel 7.0; found $KERNEL_RELEASE."
  exit 1
fi
TASK_ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
cd "$TASK_ROOT/source"
sha256sum --check SHA256SUMS
apt-get install -y build-essential dkms "linux-headers-$KERNEL_RELEASE"

DRIVER_SOURCE=/usr/src/btusb-headset-0.1
if [[ -e $DRIVER_SOURCE ]]; then
  echo "$DRIVER_SOURCE already exists; inspect the previous installation first."
  exit 1
fi
install -d "$DRIVER_SOURCE"
install -m 644 ./*.c ./*.h "$DRIVER_SOURCE/"
python3 - "$DRIVER_SOURCE/btusb.c" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
marker = "static const struct usb_device_id quirks_table[] = {"
assert text.count(marker) == 1
assert "USB_DEVICE(0x13d3, 0x3556)" not in text
addition = "\n\t/* IMC RTL8821C: run Realtek firmware setup. */\n\t{ USB_DEVICE(0x13d3, 0x3556), .driver_info = BTUSB_REALTEK |\n\t\t\t\t\t\t     BTUSB_WIDEBAND_SPEECH },\n"
text = text.replace(marker, marker + addition)
path.write_text(text)
PY
cat > "$DRIVER_SOURCE/Makefile" <<'EOF'
obj-m += btusb.o
EOF
cat > "$DRIVER_SOURCE/dkms.conf" <<'EOF'
PACKAGE_NAME="btusb-headset"
PACKAGE_VERSION="0.1"
BUILT_MODULE_NAME[0]="btusb"
DEST_MODULE_LOCATION[0]="/kernel/drivers/bluetooth"
AUTOINSTALL="yes"
EOF
dkms add -m btusb-headset -v 0.1
dkms build -m btusb-headset -v 0.1 -k "$KERNEL_RELEASE"
dkms install -m btusb-headset -v 0.1 -k "$KERNEL_RELEASE"
echo "Selected module: $(modinfo -n btusb)"
echo "Signer: $(modinfo -F signer btusb)"

if mokutil --sb-state | grep -q 'SecureBoot enabled'; then
  CERTIFICATE=""
  for candidate in /var/lib/shim-signed/mok/MOK.der /var/lib/dkms/mok.pub; do
    if [[ -f $candidate ]]; then CERTIFICATE=$candidate; break; fi
  done
  if [[ -z $CERTIFICATE ]]; then
    echo "DKMS certificate not found. Review the DKMS signing output before rebooting."
    exit 1
  fi
  if ! mokutil --test-key "$CERTIFICATE" >/dev/null 2>&1; then
    echo "Enroll the DKMS key; choose a temporary password at the following prompt."
    mokutil --import "$CERTIFICATE"
    echo "On reboot: Enroll MOK -> Continue -> Yes -> enter that password."
  fi
fi
echo "Build complete. Reboot Ubuntu when ready; this script does not reboot it."
echo "After reboot, check journalctl -k -b for RTL8821C firmware setup messages."
