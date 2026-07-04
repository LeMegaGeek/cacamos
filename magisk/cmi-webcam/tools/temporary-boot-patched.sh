#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"
fastboot_bin="${FASTBOOT:-fastboot}"
patched_img="${1:-}"

if [[ -z "$patched_img" ]]; then
    echo "Usage: $(basename "$0") /path/to/magisk-patched-boot.img" >&2
    exit 2
fi

patched_img="$(realpath "$patched_img")"
[[ -f "$patched_img" ]] || { echo "patched boot image not found: $patched_img" >&2; exit 1; }

command -v "$adb_bin" >/dev/null 2>&1 || { echo "adb not found" >&2; exit 127; }
command -v "$fastboot_bin" >/dev/null 2>&1 || { echo "fastboot not found" >&2; exit 127; }

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

detect_magisk_su() {
    if "$adb_bin" shell su -c id >/dev/null 2>&1; then
        printf 'su'
        return 0
    fi
    if "$adb_bin" shell /debug_ramdisk/su -c id >/dev/null 2>&1; then
        printf '/debug_ramdisk/su'
        return 0
    fi
    return 1
}

"$adb_bin" wait-for-device
device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
lineage="$("$adb_bin" shell getprop ro.lineage.version | tr -d '\r')"
[[ "$device" == "cmi" ]] || { echo "Expected cmi, got ${device:-unset}" >&2; exit 1; }

patched_base="$(basename "$patched_img")"
if [[ "$patched_base" =~ (20[0-9]{6}) ]]; then
    patched_date="${BASH_REMATCH[1]}"
    if [[ "$lineage" != *"$patched_date"* ]]; then
        cat >&2 <<EOF
Refusing to boot $patched_base.
The phone is running: ${lineage:-unknown}
The patched image appears to be for build date: $patched_date

Use a Magisk-patched boot image built from the exact installed LineageOS build.
EOF
        exit 1
    fi
else
    cat >&2 <<EOF
Refusing to boot $patched_base because no LineageOS build date could be inferred.
Name the file with the source build date, for example:
lineage-23.2-YYYYMMDD-nightly-cmi-boot-magisk-vXX-patched.img
EOF
    exit 1
fi

echo "Temporarily booting patched image. This does not flash the phone."
"$adb_bin" reboot bootloader
wait_for_fastboot
"$fastboot_bin" boot "$patched_img"
"$adb_bin" wait-for-device

echo "Device booted. Checking Magisk root..."
su_bin="$(detect_magisk_su || true)"
if [[ -z "$su_bin" ]]; then
    echo "Magisk root is not available through su or /debug_ramdisk/su" >&2
    exit 1
fi

"$adb_bin" shell "$su_bin" -c id
echo "Magisk root helper: $su_bin"
