# Ubuntu Test Bluetooth Headset

Use an Ubuntu PC as a pairable Bluetooth headset to test microphone input and headphone output on an iPad or Mac. PipeWire provides the classic Bluetooth Hands-Free Profile (HFP) headset role.

    DualSense microphone -> Ubuntu -> Bluetooth HFP -> iPad/Mac microphone input
    iPad/Mac audio output -> Bluetooth HFP -> Ubuntu -> Creative SXFI headphones

A continuous 440 Hz tone is available for repeatable input tests. Pair this device in normal Bluetooth settings, rather than a Bluetooth MIDI picker.

## Tested hardware and software

- Ubuntu 26.04.1, kernel 7.0.0-42-generic, PipeWire 1.6.2, WirePlumber 0.5.13.
- ASUS PRIME H610M-A WIFI D4 system with IMC/Realtek RTL8821C Bluetooth adapter, USB ID 13d3:3556.
- USB DualSense (054c:0ce6), ALSA card Controller: 48 kHz, two-channel microphone.
- Creative SXFI AMP (041e:6007), ALSA card AMP: 48 kHz stereo headphone output.
- Bluetooth name: **Ubuntu Test Headset**.

The tested Bluetooth path is mono voice audio at 8 kHz. Wideband mSBC is disabled in the configuration fragment; PipeWire converts the 48 kHz USB audio. This is a headset voice-path test, not an A2DP microphone stream.

## Ubuntu setup

Service units expect the checkout at ~/bluetooth-test-headset:

    git clone https://github.com/Michael-Z-Freeman/Ubuntu-Test-Bluetooth-Headset.git ~/bluetooth-test-headset
    cd ~/bluetooth-test-headset
    sudo apt install bluez pipewire wireplumber alsa-utils acl python3
    mkdir -p ~/.config/wireplumber/wireplumber.conf.d ~/.config/systemd/user
    cp config/wireplumber.conf.d/90-bluetooth-test-headset.conf ~/.config/wireplumber/wireplumber.conf.d/
    cp systemd/*.service ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user restart wireplumber
    bluetoothctl system-alias "Ubuntu Test Headset"

Use a logged-in desktop session where possible. For SSH-only operation, install the headless fragment too:

    cp config/wireplumber.conf.d/91-headless-bluetooth-test.conf ~/.config/wireplumber/wireplumber.conf.d/
    systemctl --user restart wireplumber

If the login screen already owns HFP, registration can fail with Address already in use or NotPermitted. The tested Ubuntu greeter user is gdm-greeter; release its audio service with:

    sudo systemctl --user --machine=gdm-greeter@.host stop wireplumber.service
    systemctl --user restart wireplumber

Other distributions may use a different greeter user. Keep an SSH session open during headless tests. Running after all sessions disconnect additionally requires user lingering, which these scripts do not enable.

## Pair the receiver

Start an interactive agent on Ubuntu:

    bluetoothctl --agent NoInputNoOutput

At its prompt:

    default-agent
    pairable on
    discoverable on

Choose Ubuntu Test Headset in the iPad/Mac's normal Bluetooth settings. Keep the agent open during pairing and answer requests for your intended device. Discovery normally expires after three minutes; repeat discoverable on if needed.

Identify and trust the paired receiver, substituting its actual address:

    bluetoothctl devices
    bluetoothctl trust AA:BB:CC:DD:EE:FF
    bluetoothctl connect AA:BB:CC:DD:EE:FF hfp-ag

Select its headset input/output in the receiving app. Close other headset connections while testing: routing helpers follow the first active HFP stream. If firmware changes cause the Mac to report an encryption-mode downgrade, forget the headset on both peers and pair afresh.

## USB microphone and headphones

SSH users may lack sound-device access. Inspect card indexes before granting temporary access:

    cat /proc/asound/cards
    getfacl /dev/snd/controlC0

On the tested boot, DualSense was card 0 and SXFI was card 1:

    sudo setfacl -m "u:$USER:rw" /dev/snd/controlC0 /dev/snd/pcmC0D0c
    sudo setfacl -m "u:$USER:rw" /dev/snd/controlC1 /dev/snd/pcmC1D0p

Recheck indexes after reboot; these ACL grants are temporary. Start both directions:

    systemctl --user start bluetooth-test-mic.service
    systemctl --user start bluetooth-test-headphones.service

The microphone helper creates **DualSense Microphone**, preserves its channel mapping, and follows the active Bluetooth uplink. Starting it stops the tone service. The output helper creates **Creative SXFI Headphones**, replaces the peer's Dummy Output links, unmutes playback, and sets both PipeWire and hardware PCM volume controls to 80%. The nearest SXFI hardware step reports 79%.

Helpers use ALSA card names Controller and AMP; edit their paths for other USB devices. User units are started explicitly and are not enabled for automatic startup. Stop a route using systemctl --user stop with the corresponding service name.

## Tone and diagnostics

For synthetic microphone input:

    systemctl --user start bluetooth-test-tone.service

To stop it and return to the microphone:

    systemctl --user stop bluetooth-test-tone.service
    systemctl --user start bluetooth-test-mic.service

PipeWire may retain an automatically selected microphone route; inspect the graph if you need a completely isolated tone.

For diagnostic capture on the receiving Mac:

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    python capture-bt-audio.py

The helper selects Ubuntu Test Headset, records 65 seconds, and writes samples/rate to /tmp/ubuntu-bt-audio.npy and /tmp/ubuntu-bt-rate.npy. macOS may request microphone access. Recordings are excluded from Git.

Useful Ubuntu checks:

    wpctl status
    pw-link -l
    bluetoothctl show
    journalctl -k -b | grep -Ei 'Bluetooth:|SCO|RTL:'
    journalctl --user -u bluetooth-test-mic -u bluetooth-test-headphones -u bluetooth-test-tone

## Optional Realtek driver backport

This targets **13d3:3556 and Linux 7.0**, not arbitrary Bluetooth adapters. Inspect firmware initialization before installing it.

Originally pairing worked, but corrupted SCO packets caused capture to disconnect after roughly six seconds. The upstream v7.0 Realtek quirk table lacked this ID and the boot log contained no Realtek setup. Adding BTUSB_REALTEK and BTUSB_WIDEBAND_SPEECH enabled RTL8821C initialization. The replacement module was built against the Ubuntu headers and loaded with Secure Boot enabled after signing-key enrollment.

Fetch hash-checked upstream files, then build/install the DKMS module:

    python3 fetch-driver-source.py
    sudo bash install-driver-backport.sh

The installer accepts kernel 7.0, installs build tools and matching headers, and retains the distribution module as fallback. It never reboots automatically. With Secure Boot enabled, an untrusted signing key must be enrolled: choose a temporary password at the enrollment prompt, reboot, and enroll it through the firmware-time MOK Manager screen. Stop if the build fails.

A reboot-free diagnostic using the existing signed driver is also provided:

    sudo bash try-stock-driver.sh

It temporarily enables the voice-buffer fix and disables USB autosuspend. It did **not** resolve sustained capture on the tested adapter.

To remove the backport:

    sudo dkms remove -m btusb-headset -v 0.1 --all

Reboot to return to the distribution module. Review the backport when changing kernels; it is not a general driver-update mechanism. Downloaded sources, compiled modules, and signing keys are excluded from Git.

## Validation and limitations

On November 1, 2026, the patched adapter loaded rtl8821c_fw.bin and rtl8821c_config.bin, firmware version 0x75b8f098. Fresh pairing was needed after the firmware change.

- Mac capture completed all 520,000 samples at 8 kHz: **65.0 seconds**, without disconnecting during capture.
- All 62 analyzed one-second windows had a dominant frequency of **440 Hz**.
- DualSense capture verified 96,000 frames at 48 kHz with nonzero microphone samples.
- Both tablet audio directions were active; SXFI playback reported RUNNING and was unmuted.

SCO warnings still appeared when capture closed, although the radio stayed connected. Apps that repeatedly start/stop capture need further validation. This is a practical test rig, not a production headset implementation.

Project scripts and documentation use the MIT license. Downloaded kernel source retains its upstream licenses; see [NOTICE.md](NOTICE.md).
