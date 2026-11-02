# speech-os

A minimal Buildroot-based OS image that turns a Raspberry Pi 4 or 5 with the
Raspberry Pi Touch Display 2 into a speech assistant appliance. It runs the
streaming speech recognizer of [speech](https://github.com/chrshdl/speech)
on the device, with no cloud service, and shows its client full screen on
the touch display: tap the microphone, speak, and the transcript and answers
appear.

- **Boots straight into the assistant**: no desktop and no login.
- **Read-only system**: a read-only rootfs in A/B slots, with the models and
  the device's state on a separate `/data` partition.
- **Locked down release images**: no SSH server and no root login. Dev images
  keep both for tinkering.

## Hardware

- Raspberry Pi 4 Model B or Raspberry Pi 5. A Pi 5 wants its 27 W (5 A)
  power supply: on a weaker one, its USB ports share 600 mA, which a
  speakerphone can exceed.
- Raspberry Pi Touch Display 2, 7" (the 5" works too, see the board's
  `config.txt`, `board/raspberrypi4-64/` or `board/raspberrypi5/`)
- A USB speakerphone or microphone, such as a Jabra Speak
- A microSD card of 8 GB or more

## Getting an image

Releases ship a factory image for the Raspberry Pi 5,
`factory-<version>-raspberrypi5.img.gz`, with the acoustic model, the
language model, the wake word model and a voice on it. Flash it, for
example with Raspberry Pi Imager, which takes the `.img.gz` as it is. Each
release also has a `legal-info` archive with the license texts and the
sources of everything in the image.

## Building

Buildroot builds on Linux only (macOS's case-insensitive file system breaks
the kernel build). Put the models into `models/`, see
[models/README.md](models/README.md): `models/sources` lists where CI gets
them, with their hashes. Then:

```sh
git clone --branch "$(cat BUILDROOT_VERSION)" https://github.com/buildroot/buildroot buildroot
make -C buildroot BR2_EXTERNAL=$(pwd) O=$(pwd)/output raspberrypi5_defconfig
make -C buildroot O=$(pwd)/output
```

and flash `output/images/sdcard.img`. The first build takes about 3 hours
on 4 cores, most of it WPE WebKit. `raspberrypi4-64_defconfig` builds for a
Pi 4, into an output directory of its own, as the toolchain is built for
the board's CPU.

That builds a dev image, with SSH and root login. A release image merges
`configs/release.fragment`: no SSH server, root locked, no serial console,
and U-Boot cannot be interrupted. CI builds it for each `v*` tag, checks
the hardening with `scripts/assert-release-image.sh`, and publishes it
with its legal info.

Two GitHub Actions workflows build images:

- `ci.yml`: the release image for each `v*` tag, published with the
  release, and a dev image of the pinned speech version when started by
  hand, or for a pull request labeled `build`, as a workflow artifact.
- `dev-image.yml`, started by hand: a dev image with any speech branch,
  tag or commit in place of the pinned one, as a workflow artifact, such as
  `gh workflow run dev-image.yml -f speech_ref=my-branch`.

## On the device

The models and the arguments of the recognizer live on the `/data`
partition, see [models/README.md](models/README.md) for swapping them.

Ethernet works out of the box. For Wi-Fi, the screen asks on first boot:
pick the network, type its password on the on-screen keyboard, and the
device joins it and remembers it. The Wi-Fi button next to the day and
night button opens the same setup later, for instance to change networks.

On a dev image, log in with `ssh root@speech.local`, password `root`.

A Pi 5 boots about a second faster with these settings in its bootloader
EEPROM, set once per board with `rpi-eeprom-config --edit` from Raspberry
Pi OS: `NET_INSTALL_ENABLED=0` (no USB scan for a keyboard's Shift key,
for network install), `NET_INSTALL_AT_POWER_ON=0`, `DISABLE_HDMI=1` (no
diagnostics screen on HDMI) and `BOOT_UART=0`.

Useful commands: `journalctl -u speech-backend -f` for the recognizer,
`journalctl -u speech-kiosk` for the display, and `arecord -l` and
`aplay -l` to see the USB audio device.

## License

All of my code is MIT licensed. Libraries follow their respective licenses.
The splash screen's unicorn is [Noto Emoji](https://github.com/googlefonts/noto-emoji)'s,
under the Apache License 2.0 (`/usr/share/licenses/noto-emoji/LICENSE` in the
image).
Release builds ship a `legal-info-*.tar.gz` next to the image with the
license manifest, license texts, and corresponding sources of everything in
the image, as collected by Buildroot's `make legal-info`.
