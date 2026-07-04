#!/usr/bin/env bash
set -euo pipefail

allow_partial=false

usage() {
    cat >&2 <<'EOF'
Usage: check-lineage-source-preflight.sh [--allow-partial] /path/to/lineageos/root

Checks that the CaCam OS cmi patch applies cleanly and that the synced
LineageOS sources contain the DeviceAsWebcam, USB HAL, SELinux and kernel UVC
pieces needed for webcam mode.

Use --allow-partial only for a deliberately partial source sync. Missing large
base projects are then reported as warnings instead of hard failures.
EOF
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'WARN: %s\n' "$*" >&2
}

ok() {
    printf 'OK: %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-partial)
            allow_partial=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            fail "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

lineage_root="${1:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
addon_dir="$(cd "$script_dir/.." && pwd)"
patch_file="$addon_dir/patches/0001-cmi-enable-cacam-os-webcam.patch"
lineage_root="$(cd "$lineage_root" && pwd)"

device_mk="$lineage_root/device/xiaomi/cmi/device.mk"
kernel_config="$lineage_root/kernel/xiaomi/sm8250/arch/arm64/configs/vendor/kona-perf_defconfig"
usb_manager="$lineage_root/frameworks/base/core/java/android/hardware/usb/UsbManager.java"
usb_gadget_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
usb_gadget_policy="$lineage_root/system/sepolicy/private/hal_usb_gadget.te"
property_contexts="$lineage_root/system/sepolicy/private/property_contexts"
webcam_pkg="$lineage_root/packages/services/DeviceAsWebcam"
overlay_dir="$lineage_root/device/xiaomi/cmi/overlay/DeviceAsWebcamCaCamOsCmi"

require_file() {
    local path="$1"
    local label="$2"

    if [[ -f "$path" ]]; then
        ok "$label is present"
        return 0
    fi

    if [[ "$allow_partial" == true ]]; then
        warn "$label is missing in this partial sync: $path"
        return 1
    fi

    fail "missing $label: $path"
}

require_dir() {
    local path="$1"
    local label="$2"

    if [[ -d "$path" ]]; then
        ok "$label is present"
        return 0
    fi

    if [[ "$allow_partial" == true ]]; then
        warn "$label is missing in this partial sync: $path"
        return 1
    fi

    fail "missing $label: $path"
}

require_grep() {
    local pattern="$1"
    local path="$2"
    local label="$3"

    if [[ ! -f "$path" ]]; then
        require_file "$path" "$label" >/dev/null || true
        return 0
    fi

    grep -q "$pattern" "$path" || fail "$label does not contain expected pattern: $pattern"
    ok "$label contains expected pattern"
}

[[ -f "$patch_file" ]] || fail "missing addon patch: $patch_file"
require_file "$device_mk" "cmi device.mk"
require_dir "$webcam_pkg" "DeviceAsWebcam package"
require_file "$usb_gadget_hal" "QTI USB gadget HAL"
require_file "$usb_gadget_policy" "USB gadget SELinux policy"
require_file "$property_contexts" "SELinux property contexts"

if grep -q 'CaCamOsDeviceAsWebcamCmi' "$device_mk" &&
    grep -q 'DeviceAsWebcam' "$device_mk" &&
    grep -q 'ro.usb.uvc.enabled=true' "$device_mk"; then
    ok "CaCam OS cmi patch already appears installed"
    require_file "$overlay_dir/Android.bp" "CaCam OS overlay Android.bp"
    require_file "$overlay_dir/AndroidManifest.xml" "CaCam OS overlay manifest"
    require_file "$overlay_dir/res/raw/physical_camera_mapping.json" "CaCam OS camera mapping"
    require_file "$overlay_dir/res/raw/physical_camera_zoom_ratio_ranges.json" "CaCam OS zoom mapping"
    require_file "$overlay_dir/res/raw/ignored_cameras.json" "CaCam OS ignored cameras"
else
    printf 'Checking CaCam OS patch applicability...\n'
    (cd "$lineage_root" && git apply --check "$patch_file")
    ok "CaCam OS cmi patch applies cleanly"
fi

require_grep 'USB_FUNCTION_UVC' "$usb_manager" "frameworks/base UsbManager"
require_grep 'GadgetFunction::UVC' "$usb_gadget_hal" "QTI USB gadget HAL"
require_grep 'uvc.0' "$usb_gadget_hal" "QTI USB gadget HAL"
require_grep 'ro.usb.uvc.enabled' "$usb_gadget_hal" "QTI USB gadget HAL"
require_grep 'get_prop(hal_usb_gadget_server, usb_uvc_enabled_prop)' "$usb_gadget_policy" "USB gadget SELinux policy"
require_grep 'ro.usb.uvc.enabled' "$property_contexts" "SELinux property contexts"

if [[ -f "$kernel_config" ]]; then
    grep -q '^CONFIG_MEDIA_USB_SUPPORT=y$' "$kernel_config" || fail "kernel config lacks CONFIG_MEDIA_USB_SUPPORT=y"
    grep -q '^CONFIG_USB_VIDEO_CLASS=y$' "$kernel_config" || fail "kernel config lacks CONFIG_USB_VIDEO_CLASS=y"
    grep -q '^CONFIG_USB_CONFIGFS_F_UVC=y$' "$kernel_config" || fail "kernel config lacks CONFIG_USB_CONFIGFS_F_UVC=y"
    ok "kernel config enables UVC host and gadget support"
else
    require_file "$kernel_config" "cmi kernel config" >/dev/null || true
fi

printf '\nPreflight complete for CaCam OS webcam mode on cmi.\n'
if [[ "$allow_partial" == true ]]; then
    printf 'Partial sync mode was allowed; run without --allow-partial before final build.\n'
fi
