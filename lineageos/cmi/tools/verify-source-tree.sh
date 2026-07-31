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
[[ -n "$lineage_root" ]] || { usage; exit 2; }
lineage_root="$(cd "$lineage_root" && pwd)"

device_dir="$lineage_root/device/xiaomi/cmi"
device_mk="$device_dir/device.mk"
device_product="$device_dir/lineage_cmi.mk"
framework_overlay="$device_dir/rro_overlays/FrameworkResOverlayDevice/res/values/config.xml"
webcam_overlay="$device_dir/rro_overlays/DeviceAsWebcamCaCamOsCmi"
kernel_config="$lineage_root/kernel/xiaomi/sm8250/arch/arm64/configs/vendor/kona-perf_defconfig"
kernel_uvc="$lineage_root/kernel/xiaomi/sm8250/drivers/usb/gadget/function/uvc_video.c"
kernel_uac2="$lineage_root/kernel/xiaomi/sm8250/drivers/usb/gadget/function/f_uac2.c"
usb_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
webcam_dir="$lineage_root/packages/services/DeviceAsWebcam"
webcam_manifest="$webcam_dir/impl/AndroidManifest.xml"
webcam_service="$webcam_dir/interface/src/com/android/deviceaswebcam/DeviceAsWebcamFgService.java"
webcam_audio="$webcam_dir/interface/src/com/android/deviceaswebcam/UsbAudioBridge.java"
settings_controller="$lineage_root/packages/apps/Settings/src/com/android/settings/homepage/CaCamOsWebcamPreferenceController.java"

for required in \
    "$device_mk" "$device_product" "$framework_overlay" "$kernel_config" \
    "$kernel_uvc" "$kernel_uac2" "$usb_hal" "$webcam_manifest" \
    "$webcam_service" "$webcam_audio" "$settings_controller"; do
    [[ -f "$required" ]] || fail "missing $required"
done

grep -q '^CACAMOS_APPLIANCE := true$' "$device_product" ||
    fail "cmi is not configured as a dedicated CaCamOS appliance"
grep -q 'ro.cacamos.version=1.2.0' "$device_product" ||
    fail "cmi does not expose CaCamOS version 1.2.0"
grep -q 'ro.cacamos.appliance=true' "$device_product" ||
    fail "cmi appliance property is missing"
grep -q 'CaCamOsDeviceAsWebcamCmi' "$device_mk" ||
    fail "cmi DeviceAsWebcam overlay is not included"
grep -q 'ro.usb.uvc.enabled=true' "$device_mk" ||
    fail "cmi UVC property is missing"
grep -q 'ro.usb.audio_gadget.enabled=true' "$device_mk" ||
    fail "cmi UAC2 property is missing"
[[ -f "$webcam_overlay/AndroidManifest.xml" ]] || fail "cmi webcam overlay is missing"
[[ -f "$webcam_overlay/res/raw/ignored_v4l2_nodes.json" ]] ||
    fail "cmi ignored V4L2-node map is missing"
ok "dedicated cmi appliance product and overlays"

grep -q '<bool name="config_usbDefaultToUvc">true</bool>' "$framework_overlay" ||
    fail "cmi does not default USB to UVC"
grep -q '<bool name="config_adbWifiAutoEnable">true</bool>' "$framework_overlay" ||
    fail "cmi does not keep authenticated wireless ADB enabled"
grep -q '<bool name="config_disableLockscreenByDefault">true</bool>' "$framework_overlay" ||
    fail "cmi does not disable the appliance lock screen"
grep -q 'service cacamos_boot_probe' "$lineage_root/system/core/rootdir/init.rc" ||
    fail "CaCamOS boot probe is missing"
ok "automatic UVC, maintenance ADB and no-lock defaults"

grep -q '^CONFIG_USB_CONFIGFS_F_UVC=y$' "$kernel_config" ||
    fail "kernel lacks UVC gadget support"
grep -q '^CONFIG_USB_CONFIGFS_F_UAC2=y$' "$kernel_config" ||
    fail "kernel lacks UAC2 gadget support"
grep -q 'kthread_queue_work(video->kworker, &video->hw_submit)' "$kernel_uvc" ||
    fail "robust asynchronous UVC request pipeline is missing"
grep -q 'missed isochronous transfer' "$kernel_uvc" ||
    fail "UVC missed-transfer recovery is missing"
grep -q 'CaCamOS Microphone' "$kernel_uac2" ||
    fail "CaCamOS UAC2 descriptors are missing"
ok "sm8250 UVC and UAC2 gadget implementation"

grep -q 'linkFunction("uac2.0", i++)' "$usb_hal" ||
    fail "QTI USB HAL does not compose UAC2 with UVC"
grep -q 'CaCamOS Webcam + Audio' "$usb_hal" ||
    fail "CaCamOS composite USB identity is missing"
grep -q 'android:persistent="true"' "$webcam_manifest" ||
    fail "DeviceAsWebcam is not persistent"
grep -q 'android:directBootAware="true"' "$webcam_manifest" ||
    fail "DeviceAsWebcam is not direct-boot aware"
grep -q 'ro.cacamos.appliance' "$webcam_service" ||
    fail "DeviceAsWebcam appliance startup is missing"
grep -q 'AudioRecord.Builder()' "$webcam_audio" ||
    fail "USB microphone bridge is missing"
grep -q 'WEBCAM_COMPONENT' "$settings_controller" ||
    fail "Settings return-to-webcam action is missing"
ok "persistent webcam UI, audio bridge and maintenance navigation"

grep -q 'USB FunctionFS transport disabled by CaCamOS USB AV-only policy' \
    "$lineage_root/packages/modules/adb/daemon/main.cpp" ||
    fail "USB cable is not reserved for standard webcam/audio functions"
grep -q 'CaCamOS recovery ADB enabled for appliance maintenance' \
    "$lineage_root/bootable/recovery/recovery_main.cpp" ||
    fail "recovery ADB maintenance policy is missing"
ok "USB AV-only policy and recovery maintenance"

printf '\nPASS: CaCamOS 1.2.0 source tree is complete for Xiaomi Mi 10 Pro (cmi).\n'
