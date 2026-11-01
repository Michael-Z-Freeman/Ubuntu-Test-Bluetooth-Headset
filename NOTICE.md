# Third-party source

This project's scripts and documentation use the MIT license in LICENSE.

fetch-driver-source.py downloads btusb.c and supporting headers from the
Linux kernel's v7.0 tag. These files retain their upstream copyright and
SPDX license declarations; they are not relicensed under this project's MIT
license. They are downloaded into the ignored source/ directory and used to
build the optional btusb kernel module.

Upstream: https://github.com/torvalds/linux/tree/v7.0/drivers/bluetooth

No Bluetooth firmware binaries, signing keys, audio recordings, or compiled
kernel modules are distributed in this repository.
