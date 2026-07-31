#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
addon_dir="$(cd "$script_dir/.." && pwd)"
patch_dir="$addon_dir/patches"
addon_version="$(tr -d '\r\n' < "$addon_dir/VERSION")"

usage() {
    printf 'Usage: %s /path/to/lineageos/root\n' "$(basename "$0")" >&2
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$addon_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "invalid CaCamOS version: $addon_version"

lineage_root="${1:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
device_product="$lineage_root/device/xiaomi/cmi/lineage_cmi.mk"
kernel_config="$lineage_root/kernel/xiaomi/sm8250/arch/arm64/configs/vendor/kona-perf_defconfig"

[[ -f "$device_product" ]] || fail "missing cmi device tree: $device_product"
[[ -f "$kernel_config" ]] || fail "missing cmi kernel tree: $kernel_config"
[[ -d "$lineage_root/packages/services/DeviceAsWebcam" ]] ||
    fail "missing packages/services/DeviceAsWebcam; sync LineageOS lineage-23.2 first"
[[ -d "$lineage_root/vendor/qcom/opensource/usb" ]] ||
    fail "missing vendor/qcom/opensource/usb; sync LineageOS lineage-23.2 first"

if grep -q '^CACAMOS_APPLIANCE := true$' "$device_product" &&
    grep -q "ro.cacamos.version=$addon_version" "$device_product"; then
    printf 'CaCamOS cmi integration already appears to be installed.\n'
    "$script_dir/verify-patch-series.sh" --match-worktrees "$lineage_root"
    "$script_dir/verify-source-tree.sh" "$lineage_root"
    exit 0
fi

"$script_dir/verify-patch-series.sh" "$lineage_root"

printf 'Applying CaCamOS cmi patch series to %s...\n' "$lineage_root"
for patch_file in "$patch_dir"/*.patch; do
    printf '  %s\n' "$(basename "$patch_file")"
    git -C "$lineage_root" apply --check "$patch_file"
    git -C "$lineage_root" apply "$patch_file"
done

"$script_dir/verify-patch-series.sh" --match-worktrees "$lineage_root"
"$script_dir/verify-source-tree.sh" "$lineage_root"

printf '\nInstalled. Build with the LineageOS cmi userdebug target.\n'
printf '  cd %s\n' "$lineage_root"
printf '  source build/envsetup.sh\n'
printf '  lunch lineage_cmi-bp4a-userdebug\n'
printf '  GOMAXPROCS=10 GOMEMLIMIT=18GiB NINJA_ARGS="-l 10" m -j10 bacon\n'
