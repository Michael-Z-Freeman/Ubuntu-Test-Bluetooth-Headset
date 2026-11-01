#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fetch hash-checked Linux v7.0 btusb sources for the optional DKMS backport."""

import hashlib
from pathlib import Path
import urllib.error
import urllib.request

SOURCES = {
    "btbcm.h": "43ab94feac41161ff6adca55002b5494117da72b968a41c972144d92b51d574e",
    "btintel.h": "bef8c2e0c150aae6349a159a95a72aab3d995615bb2d1cae49bedad35ff4b5e1",
    "btmtk.h": "4b5d3781d0d8e47e3282c53564e83892793bb4a18c5ca318e821220316bcd9f3",
    "btrtl.h": "452d4467259f1da92f0f71bb566499f1fa0e1c89ec4f5bf7412ba8c5489daaa1",
    "btusb.c": "41f323b3b6b178a6bc69991a3ba11d60c77e038d1d7fa4fd1a5aa3e50c88804c",
}
BASES = (
    "https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/bluetooth/",
    "https://cdn.jsdelivr.net/gh/torvalds/linux@v7.0/drivers/bluetooth/",
)


def main():
    destination = Path(__file__).resolve().parent / "source"
    destination.mkdir(exist_ok=True)
    for name, expected in SOURCES.items():
        target = destination / name
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
            print(name, "already verified")
            continue
        errors = []
        for base in BASES:
            try:
                with urllib.request.urlopen(base + name, timeout=20) as response:
                    data = response.read()
                if hashlib.sha256(data).hexdigest() != expected:
                    raise ValueError("source hash mismatch")
                target.write_bytes(data)
                print(name, "downloaded and verified")
                break
            except (OSError, urllib.error.URLError, ValueError) as error:
                errors.append(str(error))
        else:
            raise SystemExit("Could not fetch " + name + ": " + "; ".join(errors))
    checksums = "".join(digest + "  " + name + "\n" for name, digest in SOURCES.items())
    (destination / "SHA256SUMS").write_text(checksums)
    print("Sources ready in", destination)


if __name__ == "__main__":
    main()
