#!/usr/bin/env bash
set -euo pipefail

allow_partial=0

usage() {
    printf 'Usage: %s [--allow-partial] /path/to/lineageos/root\n' "$(basename "$0")" >&2
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-partial)
            allow_partial=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

lineage_root="${1:-}"
[[ -n "$lineage_root" ]] || { usage; exit 2; }
lineage_root="$(cd "$lineage_root" && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

required_projects=(
    device/xiaomi/cmi
    frameworks/base
    packages/services/DeviceAsWebcam
    kernel/xiaomi/sm8250
    system/sepolicy
    vendor/qcom/opensource/usb
    packages/apps/Settings
    packages/modules/adb
    vendor/lineage
    build/make
    bootable/recovery
    system/core
    build/soong
    build/blueprint
)

missing=0
for project in "${required_projects[@]}"; do
    if [[ ! -d "$lineage_root/$project/.git" ]]; then
        printf 'MISSING: %s\n' "$project" >&2
        missing=$((missing + 1))
    fi
done

if (( missing > 0 )); then
    if (( allow_partial == 1 )); then
        printf 'WARN: partial source tree; exact patch verification was skipped.\n' >&2
        exit 0
    fi
    fail "$missing required LineageOS projects are missing"
fi

device_product="$lineage_root/device/xiaomi/cmi/lineage_cmi.mk"
if grep -q '^CACAMOS_APPLIANCE := true$' "$device_product"; then
    "$script_dir/verify-patch-series.sh" --match-worktrees "$lineage_root"
    "$script_dir/verify-source-tree.sh" "$lineage_root"
else
    "$script_dir/verify-patch-series.sh" "$lineage_root"
fi

printf '\nPASS: cmi workspace is ready for the CaCamOS 1.2.0 source integration.\n'
