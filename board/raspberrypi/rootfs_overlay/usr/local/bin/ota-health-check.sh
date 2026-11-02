#!/bin/sh
# Gate for `rauc status mark-good`: report faults the IMAGE causes, never
# faults the environment causes.
#
# That means the hardware a driver/kernel regression would silently break and
# the services this image exists for, not the network (no rollback cures a
# missing Wi-Fi) and not the microphone, which the user plugs in: the backend
# answers without it, and picks it up once plugged in.
#
# Run by speech-health.service. Exiting non-zero skips mark-good, so the slot
# keeps burning boot attempts (boot.scr persists BOOT_x_LEFT) and U-Boot
# rotates to the other slot after three reboots. Deliberately NO forced reboot
# here: a genuine hardware fault (not update-related) would otherwise
# ping-pong both slots in an endless reboot loop.
#
# Checks are polled for a grace window — the backend loads its models for a
# while, and the GT911 touch probes late (goodix-rebind.service).
set -u

TRIES=30
DELAY=2

check_display() {
    # KMS display device (vc4). Without it the kiosk cannot show anything.
    ls /dev/dri/card* >/dev/null 2>&1
}

check_gpu() {
    # V3D render node - WebKit composites on it.
    ls /dev/dri/renderD* >/dev/null 2>&1
}

check_touch() {
    # At least one input device - the touchscreen is the kiosk's only input.
    ls /dev/input/event* >/dev/null 2>&1
}

check_backend() {
    # The model and the LM loaded and the API answers.
    python3 -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:8080/v1/info", timeout=2)' \
        >/dev/null 2>&1
}

check_kiosk() {
    systemctl is-active --quiet speech-kiosk.service
}

failed=""
i=0
while [ "$i" -lt "$TRIES" ]; do
    failed=""
    check_display || failed="$failed display"
    check_gpu     || failed="$failed gpu"
    check_touch   || failed="$failed touch"
    check_backend || failed="$failed backend"
    check_kiosk   || failed="$failed kiosk"

    if [ -z "$failed" ]; then
        echo "ota-health-check: all checks passed"
        exit 0
    fi
    i=$((i + 1))
    sleep "$DELAY"
done

echo "ota-health-check: FAILED checks:$failed - NOT marking slot good" >&2
exit 1
