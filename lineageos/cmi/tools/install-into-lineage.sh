#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
addon_dir="$(cd "$script_dir/.." && pwd)"
patch_file="$addon_dir/patches/0001-cmi-enable-cacam-os-webcam.patch"

usage() {
    printf 'Usage: %s /path/to/lineageos/root\n' "$(basename "$0")" >&2
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

lineage_root="${1:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
device_mk="$lineage_root/device/xiaomi/cmi/device.mk"

[[ -f "$patch_file" ]] || fail "missing addon patch: $patch_file"
[[ -f "$device_mk" ]] || fail "missing cmi device tree: $device_mk"
[[ -d "$lineage_root/packages/services/DeviceAsWebcam" ]] || fail "missing packages/services/DeviceAsWebcam; sync LineageOS lineage-23.2 first"
[[ -d "$lineage_root/vendor/qcom/opensource/usb" ]] || fail "missing vendor/qcom/opensource/usb; sync LineageOS lineage-23.2 first"

if grep -q 'CaCamOsDeviceAsWebcamCmi' "$device_mk" &&
    grep -q 'ro.usb.uvc.enabled=true' "$device_mk" &&
    grep -q 'DeviceAsWebcam' "$device_mk"; then
    printf 'CaCam OS cmi webcam addon already appears to be installed.\n'
    "$script_dir/verify-source-tree.sh" "$lineage_root"
    exit 0
fi

printf 'Checking patch against %s...\n' "$lineage_root"
git -C "$lineage_root" apply --check "$patch_file"

printf 'Applying CaCam OS cmi webcam addon...\n'
git -C "$lineage_root" apply "$patch_file"

printf 'Verifying patched tree...\n'
"$script_dir/verify-source-tree.sh" "$lineage_root"

printf '\nInstalled. Next build commands:\n'
printf '  cd %s\n' "$lineage_root"
printf '  source build/envsetup.sh\n'
printf '  breakfast cmi\n'
printf '  mka bacon\n'
