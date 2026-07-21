#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
out_dir="$repo_root/dist/magisk-test"
adb_bin="${ADB:-adb}"
fastboot_bin="${FASTBOOT:-fastboot}"

mkdir -p "$out_dir"

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

"$adb_bin" wait-for-device
device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
lineage="$("$adb_bin" shell getprop ro.lineage.version | tr -d '\r')"

if [[ "$device" != "cmi" ]]; then
    echo "Expected cmi, got ${device:-unset}" >&2
    exit 1
fi

safe_lineage="${lineage:-unknown}"
safe_lineage="${safe_lineage//[^A-Za-z0-9_.-]/_}"
out="$out_dir/${safe_lineage}-boot.img"

echo "Rebooting cmi to bootloader to fetch the exact current boot partition..."
"$adb_bin" reboot bootloader
wait_for_fastboot
rm -f "$out" "$out.sha256"
if ! "$fastboot_bin" fetch boot "$out"; then
    rm -f "$out" "$out.sha256"
    "$fastboot_bin" reboot || true
    echo "This device/bootloader does not support fastboot fetch boot." >&2
    exit 1
fi
"$fastboot_bin" reboot
"$adb_bin" wait-for-device

if [[ ! -s "$out" ]]; then
    rm -f "$out" "$out.sha256"
    echo "fastboot fetch produced an empty boot image" >&2
    exit 1
fi

sha256sum "$out" > "$out.sha256"
cat "$out.sha256"
echo "Fetched boot image: $out"
