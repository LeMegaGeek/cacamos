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

device_mk="$lineage_root/device/xiaomi/dipper/device.mk"
kernel_base_config="$lineage_root/kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/mi845_defconfig"
kernel_device_config="$lineage_root/kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/dipper.config"
usb_gadget_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
usb_gadget_policy="$lineage_root/system/sepolicy/private/hal_usb_gadget.te"
usb_device_manager="$lineage_root/frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
framework_usb_config="$lineage_root/frameworks/base/core/res/res/values/config.xml"
webcam_pkg="$lineage_root/packages/services/DeviceAsWebcam"
webcam_manifest="$webcam_pkg/impl/AndroidManifest.xml"
webcam_receiver="$webcam_pkg/interface/src/com/android/deviceaswebcam/DeviceAsWebcamReceiver.java"
webcam_service="$webcam_pkg/interface/src/com/android/deviceaswebcam/DeviceAsWebcamFgService.java"
uvc_provider="$webcam_pkg/interface/jni/UVCProvider.cpp"
overlay_dir="$lineage_root/device/xiaomi/dipper/overlay/DeviceAsWebcamCaCamOsDipper"
usb_default_overlay="$lineage_root/device/xiaomi/dipper/overlay/frameworks/base/core/res/res/values/config.xml"
kernel_uvc_function="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/f_uvc.c"
kernel_uvc_video="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/uvc_video.c"

[[ -f "$device_mk" ]] || fail "missing $device_mk"
[[ -f "$kernel_device_config" ]] || fail "missing $kernel_device_config"
[[ -d "$webcam_pkg" ]] || fail "missing $webcam_pkg"
[[ -f "$usb_device_manager" ]] || fail "missing $usb_device_manager"
[[ -f "$webcam_manifest" ]] || fail "missing $webcam_manifest"
[[ -f "$webcam_receiver" ]] || fail "missing $webcam_receiver"
[[ -f "$webcam_service" ]] || fail "missing $webcam_service"
[[ -f "$uvc_provider" ]] || fail "missing $uvc_provider"
[[ -f "$usb_gadget_hal" ]] || fail "missing $usb_gadget_hal"
[[ -f "$usb_gadget_policy" ]] || fail "missing $usb_gadget_policy"
[[ -f "$usb_default_overlay" ]] || fail "missing $usb_default_overlay"

grep -q 'DeviceAsWebcam' "$device_mk" || fail "DeviceAsWebcam is not included in dipper PRODUCT_PACKAGES"
ok "DeviceAsWebcam is included in dipper PRODUCT_PACKAGES"

grep -q 'ro.usb.uvc.enabled=true' "$device_mk" || fail "ro.usb.uvc.enabled=true is not set for dipper"
ok "ro.usb.uvc.enabled=true is set for dipper"
grep -q '<bool name="config_usbDefaultToUvc">true</bool>' "$usb_default_overlay" ||
    fail "dipper does not default USB to UVC"
grep -q '<bool name="config_usbDefaultToUvc">false</bool>' "$framework_usb_config" ||
    fail "frameworks/base does not define the UVC default resource"
grep -q 'return UsbManager.FUNCTION_UVC' "$usb_device_manager" ||
    fail "UsbDeviceManager does not keep automatic webcam mode UVC-only"
ok "dipper defaults to UVC-only after user unlock"

grep -q 'CaCamOsDeviceAsWebcamDipper' "$device_mk" || fail "CaCam OS DeviceAsWebcam overlay is not included"
[[ -f "$overlay_dir/Android.bp" ]] || fail "missing overlay Android.bp"
[[ -f "$overlay_dir/AndroidManifest.xml" ]] || fail "missing overlay AndroidManifest.xml"
[[ -f "$overlay_dir/res/raw/physical_camera_mapping.json" ]] || fail "missing physical_camera_mapping.json"
[[ -f "$overlay_dir/res/raw/physical_camera_zoom_ratio_ranges.json" ]] || fail "missing physical_camera_zoom_ratio_ranges.json"
[[ -f "$overlay_dir/res/raw/ignored_cameras.json" ]] || fail "missing ignored_cameras.json"
[[ -f "$overlay_dir/res/raw/ignored_v4l2_nodes.json" ]] || fail "missing ignored_v4l2_nodes.json"
grep -q '"/dev/video0"' "$overlay_dir/res/raw/ignored_v4l2_nodes.json" ||
    fail "ignored_v4l2_nodes.json does not ignore dipper sde_rotator /dev/video0"
grep -q '"/dev/video32"' "$overlay_dir/res/raw/ignored_v4l2_nodes.json" ||
    fail "ignored_v4l2_nodes.json does not ignore dipper codec /dev/video32"
ok "CaCam OS DeviceAsWebcam overlay is present"

grep -q 'USB_FUNCTION_UVC' "$lineage_root/frameworks/base/core/java/android/hardware/usb/UsbManager.java" ||
    fail "frameworks/base UsbManager does not expose USB_FUNCTION_UVC"
ok "frameworks/base exposes USB_FUNCTION_UVC"

grep -q 'ro.usb.uvc.enabled' "$lineage_root/system/sepolicy/private/property_contexts" ||
    fail "system sepolicy does not define ro.usb.uvc.enabled"
ok "system sepolicy defines ro.usb.uvc.enabled"
grep -q 'get_prop(system_server, usb_uvc_enabled_prop)' "$lineage_root/system/sepolicy/private/system_server.te" ||
    fail "system_server sepolicy cannot read usb_uvc_enabled_prop"
ok "system_server sepolicy can read usb_uvc_enabled_prop"

grep -q 'GadgetFunction::UVC' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not handle GadgetFunction::UVC"
grep -q 'uvc.0' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not link uvc.0"
grep -q 'ro.usb.uvc.enabled' "$usb_gadget_hal" || fail "QTI USB gadget HAL does not gate UVC on ro.usb.uvc.enabled"
ok "QTI USB gadget HAL supports UVC"

grep -q 'get_prop(hal_usb_gadget_server, usb_uvc_enabled_prop)' "$usb_gadget_policy" ||
    fail "hal_usb_gadget_server cannot read usb_uvc_enabled_prop"
ok "USB gadget HAL sepolicy can read ro.usb.uvc.enabled"

grep -q 'com.android.DeviceAsWebcam.action.PREPARE_UVC' "$usb_device_manager" ||
    fail "UsbDeviceManager does not pre-wake DeviceAsWebcam before UVC pull-up"
grep -q 'prepareDeviceAsWebcamServiceIfNeeded(config)' "$usb_device_manager" ||
    fail "UsbDeviceManager does not call the DeviceAsWebcam pre-wake hook"
grep -q 'com.android.DeviceAsWebcam.action.PREPARE_UVC' "$webcam_manifest" ||
    fail "DeviceAsWebcam manifest does not receive the PREPARE_UVC action"
grep -q 'ACTION_PREPARE_UVC' "$webcam_receiver" ||
    fail "DeviceAsWebcam receiver does not handle the PREPARE_UVC action"
grep -q 'setupServicesAndStartListeningWithRetry' "$webcam_service" ||
    fail "DeviceAsWebcam service does not retry while waiting for the UVC node"
ok "DeviceAsWebcam is pre-warmed before host UVC enumeration"

grep -q "Complete the host's SET_INTERFACE" "$uvc_provider" ||
    fail "DeviceAsWebcam does not queue the first frame before STREAMON"
grep -q 'getDefaultUvcFormats' "$uvc_provider" ||
    fail "DeviceAsWebcam lacks the MI8 fallback UVC formats"
ok "DeviceAsWebcam carries the tested MI8 UVC negotiation and first-frame fixes"

grep -q '^CONFIG_MEDIA_USB_SUPPORT=y$' "$kernel_device_config" || fail "dipper kernel config lacks CONFIG_MEDIA_USB_SUPPORT=y"
grep -q '^CONFIG_USB_VIDEO_CLASS=y$' "$kernel_device_config" || fail "dipper kernel config lacks CONFIG_USB_VIDEO_CLASS=y"
grep -q '^CONFIG_USB_CONFIGFS_F_UVC=y$' "$kernel_device_config" || fail "dipper kernel config lacks CONFIG_USB_CONFIGFS_F_UVC=y"
ok "dipper kernel config enables UVC host and gadget support"

grep -q 'uvc_function_setup_continue' "$kernel_uvc_function" ||
    fail "MI8 UVC gadget does not delay SET_INTERFACE completion"
grep -q 'uvc_video_all_requests_free' "$kernel_uvc_video" ||
    fail "MI8 UVC gadget does not drain requests before stream shutdown"
ok "MI8 UVC gadget carries the tested stream lifecycle fixes"

if [[ -f "$kernel_base_config" ]]; then
    grep -q '^CONFIG_USB_GADGET=y$' "$kernel_base_config" || fail "mi845 base kernel config lacks CONFIG_USB_GADGET=y"
    grep -q '^CONFIG_USB_CONFIGFS=y$' "$kernel_base_config" || fail "mi845 base kernel config lacks CONFIG_USB_CONFIGFS=y"
    grep -q '^CONFIG_MEDIA_SUPPORT=y$' "$kernel_base_config" || fail "mi845 base kernel config lacks CONFIG_MEDIA_SUPPORT=y"
    ok "mi845 base kernel config has media, gadget and configfs support"
else
    printf 'WARN: kernel base config not found locally: %s\n' "$kernel_base_config" >&2
    printf 'WARN: sync kernel/xiaomi/sdm845 before final build verification.\n' >&2
fi

printf '\nSource tree is ready to build CaCam OS webcam mode for dipper.\n'
