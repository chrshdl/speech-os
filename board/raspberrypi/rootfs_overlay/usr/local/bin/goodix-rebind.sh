#!/bin/sh
# Work around the Goodix GT911 touch controller failing to probe at boot.
#
# On the Raspberry Pi Touch Display 2 (vc4-kms-dsi-ili9881-7inch overlay) the
# touch's power/reset is sequenced by the panel MCU (display_mcu@45,
# raspberrypi,v2-touchscreen-panel-regulator) as part of DSI panel bring-up.
# The goodix i2c driver probes at ~t=4.2s, before the panel is ready, and
# fails with EIO (-5), so no input device is created and ALL touch is dead.
# Bumping the touch regulator's startup-delay does NOT help (verified) - the
# dependency is the panel coming up, not power settling. Rebinding the driver
# once the panel is up succeeds.
#
# This unit retries the bind until the input device appears, then exits. It is
# ordered Before=speech-kiosk.service so the browser starts with the touch
# present. It can run before the GT911's i2c device exists (~t=3.7s, once
# udev has loaded the i2c mux module), so whether the panel has a Goodix touch
# comes from the device tree, which is complete from the start. On panels
# without one it no-ops immediately.
set -u

DRV=/sys/bus/i2c/drivers/Goodix-TS

ready() { grep -qi goodix /proc/bus/input/devices 2>/dev/null; }

# An enabled device tree node for a GT911 (no status, or status "okay").
in_device_tree() {
    for c in $(find /sys/firmware/devicetree/base -name compatible); do
        grep -q "goodix,gt911" "$c" 2>/dev/null || continue
        s="$(dirname "$c")/status"
        if [ ! -e "$s" ] || [ "$(tr -d '\0' < "$s")" = "okay" ]; then
            return 0
        fi
    done
    return 1
}

# The GT911 i2c device (e.g. 10-005d), empty until it is created.
find_dev() {
    for d in /sys/bus/i2c/devices/*; do
        if [ "$(cat "$d/name" 2>/dev/null)" = "gt911" ]; then
            basename "$d"
            return
        fi
    done
}

if ! in_device_tree; then
    echo "goodix-rebind: no Goodix touch present, nothing to do"
    exit 0
fi

dev=
i=0
while [ "$i" -lt 30 ]; do
    # Probed cleanly, by the kernel's own deferred probe or our last bind?
    if ready; then
        echo "goodix-rebind: touch up ($dev) after $i retries"
        exit 0
    fi
    [ -n "$dev" ] || dev=$(find_dev)
    if [ -n "$dev" ] && [ -e "$DRV/bind" ]; then
        echo "$dev" > "$DRV/bind" 2>/dev/null
        if ready; then
            echo "goodix-rebind: touch up ($dev) after $i retries"
            exit 0
        fi
        # bind failed -> driver auto-unbinds on probe error; the explicit
        # unbind is a harmless no-op that guarantees a clean state before
        # the next attempt.
        echo "$dev" > "$DRV/unbind" 2>/dev/null
    fi
    i=$((i + 1))
    sleep 1
done

echo "goodix-rebind: FAILED to bind ${dev:-the GT911} after $i attempts" >&2
exit 1
