#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s /path/to/lineageos/root\n' "$(basename "$0")" >&2
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'OK: %s\n' "$*"
}

lineage_root="${1:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"

device_mk="$lineage_root/device/xiaomi/cmi/device.mk"
kernel_config="$lineage_root/kernel/xiaomi/sm8250/arch/arm64/configs/vendor/kona-perf_defconfig"
usb_gadget_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
usb_gadget_policy="$lineage_root/system/sepolicy/private/hal_usb_gadget.te"
webcam_pkg="$lineage_root/packages/services/DeviceAsWebcam"
overlay_dir="$lineage_root/device/xiaomi/cmi/overlay/DeviceAsWebcamCaCamOsCmi"

[[ -f "$device_mk" ]] || fail "missing $device_mk"
[[ -d "$webcam_pkg" ]] || fail "missing $webcam_pkg"
[[ -f "$usb_gadget_hal" ]] || fail "missing $usb_gadget_hal"
[[ -f "$usb_gadget_policy" ]] || fail "missing $usb_gadget_policy"

grep -q 'DeviceAsWebcam' "$device_mk" || fail "DeviceAsWebcam is not included in cmi PRODUCT_PACKAGES"
ok "DeviceAsWebcam is included in cmi PRODUCT_PACKAGES"

grep -q 'ro.usb.uvc.enabled=true' "$device_mk" || fail "ro.usb.uvc.enabled=true is not set for cmi"
ok "ro.usb.uvc.enabled=true is set for cmi"

grep -q 'CaCamOsDeviceAsWebcamCmi' "$device_mk" || fail "CaCam OS DeviceAsWebcam overlay is not included"
[[ -f "$overlay_dir/Android.bp" ]] || fail "missing overlay Android.bp"
[[ -f "$overlay_dir/AndroidManifest.xml" ]] || fail "missing overlay AndroidManifest.xml"
[[ -f "$overlay_dir/res/raw/physical_camera_mapping.json" ]] || fail "missing physical_camera_mapping.json"
[[ -f "$overlay_dir/res/raw/physical_camera_zoom_ratio_ranges.json" ]] || fail "missing physical_camera_zoom_ratio_ranges.json"
[[ -f "$overlay_dir/res/raw/ignored_cameras.json" ]] || fail "missing ignored_cameras.json"
ok "CaCam OS DeviceAsWebcam overlay is present"

grep -q 'USB_FUNCTION_UVC' "$lineage_root/frameworks/base/core/java/android/hardware/usb/UsbManager.java" ||
    fail "frameworks/base UsbManager does not expose USB_FUNCTION_UVC"
ok "frameworks/base exposes USB_FUNCTION_UVC"

grep -q 'ro.usb.uvc.enabled' "$lineage_root/system/sepolicy/private/property_contexts" ||
    fail "system sepolicy does not define ro.usb.uvc.enabled"
ok "system sepolicy defines ro.usb.uvc.enabled"

grep -q 'GadgetFunction::UVC' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not handle GadgetFunction::UVC"
grep -q 'uvc.0' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not link uvc.0"
grep -q 'ro.usb.uvc.enabled' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not gate UVC on ro.usb.uvc.enabled"
ok "QTI USB gadget HAL supports UVC"

grep -q 'get_prop(hal_usb_gadget_server, usb_uvc_enabled_prop)' "$usb_gadget_policy" ||
    fail "hal_usb_gadget_server cannot read usb_uvc_enabled_prop"
ok "USB gadget HAL sepolicy can read ro.usb.uvc.enabled"

if [[ -f "$kernel_config" ]]; then
    grep -q '^CONFIG_MEDIA_USB_SUPPORT=y$' "$kernel_config" || fail "kernel config lacks CONFIG_MEDIA_USB_SUPPORT=y"
    grep -q '^CONFIG_USB_VIDEO_CLASS=y$' "$kernel_config" || fail "kernel config lacks CONFIG_USB_VIDEO_CLASS=y"
    grep -q '^CONFIG_USB_CONFIGFS_F_UVC=y$' "$kernel_config" || fail "kernel config lacks CONFIG_USB_CONFIGFS_F_UVC=y"
    ok "kernel config enables UVC host and gadget support"
else
    printf 'WARN: kernel config not found locally: %s\n' "$kernel_config" >&2
    printf 'WARN: sync kernel/xiaomi/sm8250 before final build verification.\n' >&2
fi

printf '\nSource tree is ready to build CaCam OS webcam mode for cmi.\n'
