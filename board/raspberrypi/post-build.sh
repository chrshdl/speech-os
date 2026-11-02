#!/bin/sh
set -eu

# Shared by the boards. $TARGET_DIR is passed by Buildroot, and $2 is the
# board's directory, BR2_ROOTFS_POST_SCRIPT_ARGS in its defconfig.
T="${TARGET_DIR}"
BOARD_DIR="${2:?usage: post-build.sh <target-dir> <board-dir>}"

# Buildroot exports BR2_CONFIG, but we set a default just in case
BR2_CONFIG="${BR2_CONFIG:-.config}"

case "$(basename "$BOARD_DIR")" in
    raspberrypi4-64)
        COMPAT_STR="SpeechOS-RPi4"
        BOARD_NAME="Raspberry Pi 4 B"
        ;;
    raspberrypi5)
        COMPAT_STR="SpeechOS-RPi5"
        BOARD_NAME="Raspberry Pi 5"
        ;;
    *)
        echo "POST-BUILD ERROR: unknown board directory $BOARD_DIR" >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# Update RAUC Configuration
# ------------------------------------------------------------------------------
if [ -f "$T/etc/rauc/system.conf" ]; then
    sed -i "s/@BOARD_COMPATIBLE@/$COMPAT_STR/g" "$T/etc/rauc/system.conf"
    echo "POST-BUILD: Configured RAUC system.conf for $COMPAT_STR"
fi

# ------------------------------------------------------------------------------
# Generate /etc/os-release
# ------------------------------------------------------------------------------
# Buildroot generated its own os-release earlier in target-finalize (and
# /etc/os-release symlinks to /usr/lib/os-release, so the heredoc below
# replaces it) — capture the Buildroot version first.
BUILDROOT_VERSION="$(sed -n 's/^VERSION_ID=//p' "$T/usr/lib/os-release" 2>/dev/null | tr -d '"')"
[ -n "$BUILDROOT_VERSION" ] || BUILDROOT_VERSION="${BR2_VERSION_FULL:-unknown}"

cat <<EOF > "$T/etc/os-release"
NAME="SpeechOS"
ID=speech-os
PRETTY_NAME="Speech OS ($BOARD_NAME)"
BUILD_ID=$(date +%Y%m%d%H%M)
VARIANT_ID=$COMPAT_STR
BUILDROOT_VERSION="$BUILDROOT_VERSION"
EOF

# The OS release version (the git tag, e.g. v0.1.0) is passed in by CI on
# tagged builds. Local/PR builds omit it.
if [ -n "${SPEECH_OS_VERSION:-}" ]; then
    echo "VERSION_ID=\"$SPEECH_OS_VERSION\"" >> "$T/etc/os-release"
fi

echo "POST-BUILD: Generated /etc/os-release"

# ------------------------------------------------------------------------------
# Systemd Tweaks
# ------------------------------------------------------------------------------
# Mask the generic wpa_supplicant unit so only the @wlan0 instance runs.
ln -snf /dev/null "$T/etc/systemd/system/wpa_supplicant.service"
rm -f "$T/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service" 2>/dev/null || true

# ------------------------------------------------------------------------------
# Build integrity (all variants — not release-specific)
# ------------------------------------------------------------------------------
# Kernel modules must actually be loadable. Buildroot's LINUX_RUN_DEPMOD
# target-finalize hook has already run by the time post-build scripts execute,
# so the tables below are final. depmod runs on the HOST and needs a
# decompressor matching the kernel's CONFIG_MODULE_COMPRESS_*
# (BR2_PACKAGE_HOST_KMOD_GZ / _XZ / _ZSTD). When those disagree, depmod cannot
# read a single .ko and fails SILENTLY, leaving empty tables — udev then
# resolves no aliases and autoloads nothing: with bcm2711_defconfig and
# bcm2712_defconfig that is the DSI panel, the touch controller and USB audio.
for moddir in "$T"/lib/modules/*/; do
    [ -d "$moddir/kernel" ] || continue   # fully built-in kernel: nothing to check
    if [ ! -s "$moddir/modules.dep" ]; then
        echo "POST-BUILD ERROR: ${moddir}modules.dep is empty although modules are installed." >&2
        echo "  host depmod could not read them — BR2_PACKAGE_HOST_KMOD_GZ/_XZ/_ZSTD" >&2
        echo "  must match the kernel's CONFIG_MODULE_COMPRESS_*." >&2
        exit 1
    fi
    if ! grep -q "^alias " "$moddir/modules.alias" 2>/dev/null; then
        echo "POST-BUILD ERROR: ${moddir}modules.alias has no alias entries —" >&2
        echo "  udev cannot autoload any driver (same cause as an empty modules.dep)." >&2
        exit 1
    fi
    echo "POST-BUILD: module tables OK ($(wc -l < "$moddir/modules.dep") deps, $(grep -c "^alias " "$moddir/modules.alias") aliases)"
done

# The application itself must be in the image. Buildroot will happily produce
# a complete, bootable rootfs with a package missing, for instance when a
# stale build/python-speech-* stamp directory makes it skip the package. "The
# build succeeded" is not evidence that the app is in it.
for f in \
    usr/lib/speech/backend.py \
    usr/lib/speech/web/assistant/index.html \
    usr/lib/systemd/system/speech-backend.service; do
    if [ ! -e "$T/$f" ]; then
        echo "POST-BUILD ERROR: /$f is not in the rootfs. A stale" >&2
        echo "  output*/build/python-speech-* directory will do this —" >&2
        echo "  remove it and rebuild." >&2
        exit 1
    fi
done
if ! ls "$T"/usr/lib/python3.*/site-packages/onnxruntime/capi/onnxruntime_pybind11_state.*.so >/dev/null 2>&1; then
    echo "POST-BUILD ERROR: onnxruntime's native module is not in the rootfs." >&2
    exit 1
fi
echo "POST-BUILD: speech backend and onnxruntime present"

# ------------------------------------------------------------------------------
# Release Hardening
# ------------------------------------------------------------------------------
# The shared rootfs overlay always ships sshd config for dev images; release
# builds (configs/release.fragment) drop OpenSSH itself — remove the now-inert
# config so shipped images contain no SSH artifacts at all. CI's
# assert-release-image.sh verifies this on the built rootfs.ext4.
if ! grep -q "^BR2_PACKAGE_OPENSSH=y" "$BR2_CONFIG"; then
    rm -rf "$T/etc/ssh" "$T/etc/systemd/system/sshd.service.d"
    echo "POST-BUILD: OpenSSH not in config — removed SSH overlay leftovers"

    # No local login prompt in shipped images: mask the getty templates so
    # systemd's getty-generator cannot spawn a login shell on the serial
    # console (or any console). Root is locked in release, but the prompt
    # itself is still attack surface; post-image.sh additionally drops the
    # serial console from boot.scr and disables UART/U-Boot interruption.
    # CI's assert-release-image.sh verifies the masking on the built rootfs.
    ln -snf /dev/null "$T/etc/systemd/system/serial-getty@.service"
    ln -snf /dev/null "$T/etc/systemd/system/console-getty.service"
    ln -snf /dev/null "$T/etc/systemd/system/getty@.service"
    rm -f "$T/etc/systemd/system/getty.target.wants/"*getty* 2>/dev/null || true
    echo "POST-BUILD: release — masked getty templates (no local login prompt)"
fi

exit 0
