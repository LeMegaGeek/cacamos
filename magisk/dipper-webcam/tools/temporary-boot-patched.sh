#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"
fastboot_bin="${FASTBOOT:-fastboot}"
patched_img="${1:-}"

usage() {
    cat >&2 <<'EOF'
Usage:
  temporary-boot-patched.sh /path/to/dipper-cacam-uvc-magisk-patched.img

If Android is already booted with authorized ADB, the script verifies that the
connected phone is dipper and that the image build date matches the installed
LineageOS build before rebooting to bootloader.

If the phone is already in fastboot, only the filename date check can be used.
EOF
}

if [[ -z "$patched_img" ]]; then
    usage
    exit 2
fi

patched_img="$(realpath "$patched_img")"
[[ -f "$patched_img" ]] || { echo "patched boot image not found: $patched_img" >&2; exit 1; }

command -v "$adb_bin" >/dev/null 2>&1 || { echo "adb not found" >&2; exit 127; }
command -v "$fastboot_bin" >/dev/null 2>&1 || { echo "fastboot not found" >&2; exit 127; }

patched_base="$(basename "$patched_img")"
if [[ "$patched_base" =~ (20[0-9]{6}) ]]; then
    patched_date="${BASH_REMATCH[1]}"
else
    cat >&2 <<EOF
Refusing to boot $patched_base because no LineageOS build date could be inferred.
Name the file with the source build date, for example:
lineage-22.2-YYYYMMDD-nightly-dipper-cacam-uvc-magisk-vXX-patched.img
EOF
    exit 1
fi

wait_for_fastboot() {
    for _ in $(seq 1 60); do
        if "$fastboot_bin" devices | grep -q .; then
            return 0
        fi
        sleep 1
    done
    echo "fastboot device not detected" >&2
    return 1
}

adb_state="$("$adb_bin" get-state 2>/dev/null || true)"
if [[ "$adb_state" == "device" ]]; then
    device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
    lineage="$("$adb_bin" shell getprop ro.lineage.version | tr -d '\r')"
    [[ "$device" == "dipper" ]] || { echo "Expected dipper, got ${device:-unset}" >&2; exit 1; }

    if [[ "$lineage" != *"$patched_date"* ]]; then
        cat >&2 <<EOF
Refusing to boot $patched_base.
The phone is running: ${lineage:-unknown}
The patched image appears to be for build date: $patched_date

Use a patched boot image built from the exact installed LineageOS build.
EOF
        exit 1
    fi

    echo "Temporarily booting patched image. This does not flash the phone."
    "$adb_bin" reboot bootloader
    wait_for_fastboot
elif "$fastboot_bin" devices | grep -q .; then
    echo "Phone is already in fastboot; booting without ADB build verification."
else
    cat >&2 <<EOF
No authorized ADB device and no fastboot device detected.
Authorize ADB in Android, or manually put the MI8 in fastboot mode.
EOF
    exit 1
fi

"$fastboot_bin" boot "$patched_img"

echo "Boot command sent. Once Android is up, authorize ADB and run:"
echo "  ./cacam-os/magisk/dipper-webcam/install-via-adb.sh"
