#!/bin/bash

set -e

# Shared by the boards. $1 is the images directory (output/images), passed by
# Buildroot, and $2 the board's directory, BR2_ROOTFS_POST_SCRIPT_ARGS in its
# defconfig, with its boot.cmd and genimage.cfg.
BINARIES_DIR="$1"
BOARD_DIR="${2:?usage: post-image.sh <images-dir> <board-dir>}"
COMMON_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
# The acoustic model and the LM that go onto /data, see models/README.md.
MODELS_DIR="${SPEECH_MODELS_DIR:-$(cd "${COMMON_DIR}/../.." && pwd)/models}"

# Release variant, same detection as post-build.sh: configs/release.fragment
# drops OpenSSH.
RELEASE=
grep -q "^BR2_PACKAGE_OPENSSH=y" "${BR2_CONFIG}" || RELEASE=1

# The serial console= arguments, which release builds remove.
SERIAL_CONSOLE_RE='s/ console=tty\(S\|AMA\)[0-9]*,[0-9]*//'

# 1. Compile U-Boot script (boot.cmd -> boot.scr)
# This is the "brain" of the A/B switching logic.
# Requires 'host-uboot-tools' to be enabled in menuconfig.
# Its bootargs are the kernel command line (cmdline.txt is not used), so a
# release build compiles a copy without the serial console.
if [ -f "${BOARD_DIR}/boot.cmd" ]; then
    BOOT_CMD="${BOARD_DIR}/boot.cmd"
    if [ -n "${RELEASE}" ]; then
        BOOT_CMD="${BUILD_DIR}/boot-release.cmd"
        sed "${SERIAL_CONSOLE_RE}" "${BOARD_DIR}/boot.cmd" > "${BOOT_CMD}"
    fi
    echo "Generating boot.scr from ${BOOT_CMD}..."
    "${HOST_DIR}/bin/mkimage" -A arm64 -T script -C none -n "U-Boot boot script" \
        -d "${BOOT_CMD}" "${BINARIES_DIR}/boot.scr"
fi

# 2. Release hardening of the other boot artifacts. Dev builds keep
# serial console + interruptible U-Boot for the bench workflow (bootdelay=0
# waits for no key, which saves a second on every boot, but a key typed on the
# serial console while U-Boot starts still stops it).
# Only the staged copies in BINARIES_DIR are touched, never the source tree.
# CI's assert-release-image.sh verifies all of it on the built artifacts.
if [ -n "${RELEASE}" ]; then
    echo "POST-IMAGE: release — hardening boot artifacts"

    # No serial console: kernel logs/getty stay off the UART (boot.scr
    # above; cmdline.txt too, which only a boot without U-Boot reads)...
    sed -i "${SERIAL_CONSOLE_RE}" "${BINARIES_DIR}/rpi-firmware/cmdline.txt"
    # ...and the UART is not brought up by the firmware at all.
    sed -i 's/^enable_uart=1/enable_uart=0/' "${BINARIES_DIR}/rpi-firmware/config.txt"

    # Non-interruptible U-Boot, two independent ways: bootdelay=-2 autoboots
    # without ever calling abortboot, and stdin is pointed at "nulldev", whose
    # tstc() always returns 0 (common/stdio.c) — so even if bootdelay were
    # somehow reset, no keypress can be seen.
    #
    # It MUST name a device that exists: console_init_r() falls back to
    # serial when the named input device is not registered, so a bogus name
    # gives the image a live serial console. assert-release-image.sh asserts
    # stdin=nulldev positively for that reason.
    #
    # Regenerate the redundant env image from a hardened copy of
    # uboot-env.txt; size/redundancy must match the defconfig's
    # BR2_PACKAGE_HOST_UBOOT_TOOLS_ENVIMAGE_SIZE/_REDUNDANT (0x4000, -r).
    sed -e 's/^bootdelay=.*/bootdelay=-2/' \
        -e 's/^stdin=.*/stdin=nulldev/' \
        "${COMMON_DIR}/uboot-env.txt" > "${BUILD_DIR}/uboot-env-release.txt"
    "${HOST_DIR}/bin/mkenvimage" -r -s 0x4000 \
        -o "${BINARIES_DIR}/uboot-env.bin" "${BUILD_DIR}/uboot-env-release.txt"
fi

# 3. Stage the /data partition: the acoustic model, the LM, the songs, the
# voice, the wake word model, the voice activity detector, and the arguments
# speech-backend.service starts backend.py with. They live on
# /data rather than in the rootfs so they survive A/B updates and can be
# swapped on the device without a new image.
trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

shopt -s nullglob
models=("${MODELS_DIR}"/*.onnx)
lms=("${MODELS_DIR}"/*.npz)
# The songs it plays when asked, such as "play twinkle twinkle", which may be
# none: only the .json files, see speech's speech/backend/songs.py.
songs=("${MODELS_DIR}"/songs/*.json)
# The Piper voice it speaks answers with, such as the weather, which may be
# none: an .onnx file with its .onnx.json config, see models/README.md.
voices=("${MODELS_DIR}"/voice/*.onnx)
# The wake word model, such as olivia.onnx, which starts a capture when the
# wake word is heard, and the voice activity detector, Silero VAD, in front
# of it, each of which may be none, see models/README.md.
wake_words=("${MODELS_DIR}"/wake-word/*.onnx)
vads=("${MODELS_DIR}"/vad/*.onnx)
shopt -u nullglob

if [ "${#models[@]}" -ne 1 ]; then
    echo "POST-IMAGE ERROR: ${MODELS_DIR} must hold exactly one acoustic model (*.onnx)," >&2
    echo "  found ${#models[@]}. Export one with speech's export.py, see models/README.md." >&2
    exit 1
fi
if [ "${#lms[@]}" -gt 1 ]; then
    echo "POST-IMAGE ERROR: ${MODELS_DIR} holds ${#lms[@]} LMs (*.npz), at most one is used." >&2
    exit 1
fi
if [ "${#voices[@]}" -gt 1 ]; then
    echo "POST-IMAGE ERROR: ${MODELS_DIR}/voice holds ${#voices[@]} voices (*.onnx), at most one is used." >&2
    exit 1
fi
if [ "${#wake_words[@]}" -gt 1 ] || [ "${#vads[@]}" -gt 1 ]; then
    echo "POST-IMAGE ERROR: ${MODELS_DIR}/wake-word and ${MODELS_DIR}/vad hold at most one model (*.onnx) each," >&2
    echo "  found ${#wake_words[@]} and ${#vads[@]}." >&2
    exit 1
fi
if [ "${#voices[@]}" -eq 1 ] && [ ! -f "${voices[0]}.json" ]; then
    echo "POST-IMAGE ERROR: $(basename "${voices[0]}") has no $(basename "${voices[0]}").json, its config." >&2
    exit 1
fi
for f in "${models[@]}" "${lms[@]}" "${voices[@]}" "${wake_words[@]}" "${vads[@]}"; do
    case "$(basename "$f")" in
        *[[:space:]]*)
            # systemd splits SPEECH_ARGS on whitespace.
            echo "POST-IMAGE ERROR: rename '$(basename "$f")', the name has whitespace." >&2
            exit 1
            ;;
    esac
done

mkdir -p "${ROOTPATH_TMP}/data/speech/songs" "${ROOTPATH_TMP}/data/etc"
# -L: models/ may hold symlinks into the speech checkout.
cp -L "${models[@]}" "${lms[@]}" "${ROOTPATH_TMP}/data/speech/"
if [ "${#songs[@]}" -gt 0 ]; then
    cp -L "${songs[@]}" "${ROOTPATH_TMP}/data/speech/songs/"
fi
if [ "${#voices[@]}" -eq 1 ]; then
    mkdir -p "${ROOTPATH_TMP}/data/speech/voice"
    cp -L "${voices[0]}" "${voices[0]}.json" "${ROOTPATH_TMP}/data/speech/voice/"
fi
for f in "${wake_words[@]}" "${vads[@]}"; do
    dir="$(basename "$(dirname "$f")")"
    mkdir -p "${ROOTPATH_TMP}/data/speech/${dir}"
    cp -L "$f" "${ROOTPATH_TMP}/data/speech/${dir}/"
done

args="/data/speech/$(basename "${models[0]}")"
if [ "${#lms[@]}" -eq 1 ]; then
    args="${args} --lm /data/speech/$(basename "${lms[0]}")"
fi
# The decoding settings tuned for this model and LM, such as the LM's
# weight, which may be none, see models/README.md.
if [ -f "${MODELS_DIR}/backend-args" ]; then
    extra=$(grep -v '^[[:space:]]*#' "${MODELS_DIR}/backend-args" | tr '\n' ' ' | xargs)
    args="${args}${extra:+ ${extra}}"
fi
# The client's Wi-Fi setup, the only way to join a network on a release
# image. The service listens on 127.0.0.1 only, so only the kiosk reaches it.
args="${args} --wifi-interface wlan0"
# Songs, the Touch Display's brightness and the USB speakerphone's volume,
# which the backend keeps in /data/speech/state (made by
# prepare-data-dirs.service, as the speech user's). usbaudio is the
# speakerphone's card, see 85-usb-audio.rules, and PCM the control its own
# buttons turn.
args="${args} --songs /data/speech/songs --backlight auto --state-dir /data/speech/state"
args="${args} --volume-control usbaudio:PCM"
# A capture that hears nothing, such as after the wake word alone, ends after
# 5 seconds rather than the backend's 8.
args="${args} --no-speech-timeout 5"
if [ "${#wake_words[@]}" -eq 1 ]; then
    args="${args} --wake-word /data/speech/wake-word/$(basename "${wake_words[0]}")"
fi
if [ "${#vads[@]}" -eq 1 ]; then
    args="${args} --vad /data/speech/vad/$(basename "${vads[0]}")"
fi
# Last, so speech-preload.service reads the voice into the page cache after
# the model and the LM, which the backend needs first.
if [ "${#voices[@]}" -eq 1 ]; then
    args="${args} --voice /data/speech/voice/$(basename "${voices[0]}")"
fi
cat > "${ROOTPATH_TMP}/data/etc/speech-backend" <<EOF
# The arguments of /usr/lib/speech/backend.py, see
# \`python3 /usr/lib/speech/backend.py -h\`. After a change, run
# \`systemctl restart speech-backend\`.
SPEECH_ARGS=${args}
EOF
chmod -R u=rwX,go=rX "${ROOTPATH_TMP}/data"
echo "POST-IMAGE: /data gets $(basename "${models[0]}")${lms:+ and $(basename "${lms[0]}")}, ${#songs[@]} song(s)${voices:+, the voice $(basename "${voices[0]}")}${wake_words:+, the wake word $(basename "${wake_words[0]}")}${vads:+, the VAD $(basename "${vads[0]}")}"

# 4. Generate the SD Card Image
# Under fakeroot so the files on /data belong to root, not to whoever ran
# the build (mke2fs -d copies the owners of the staged files).
rm -rf "${GENIMAGE_TMP}"

"${HOST_DIR}/bin/fakeroot" -- /bin/sh -c 'chown -R 0:0 "$1" && shift && exec genimage "$@"' sh \
    "${ROOTPATH_TMP}" \
    --rootpath "${ROOTPATH_TMP}"   \
    --tmppath "${GENIMAGE_TMP}"    \
    --inputpath "${BINARIES_DIR}"  \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"
