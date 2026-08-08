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
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cacamos_version="$(tr -d '\r\n' < "$script_dir/../VERSION")"
[[ "$cacamos_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "invalid CaCamOS version: $cacamos_version"

device_dir="$lineage_root/device/xiaomi/cmi"
device_mk="$device_dir/device.mk"
device_product="$device_dir/lineage_cmi.mk"
device_variant="$device_dir/libinit/libvariant_xiaomi_cmi.cpp"
device_releasetools="$device_dir/releasetools.py"
framework_overlay="$device_dir/rro_overlays/FrameworkResOverlayDevice/res/values/config.xml"
webcam_overlay="$device_dir/rro_overlays/DeviceAsWebcamCaCamOsCmi"
kernel_config="$lineage_root/kernel/xiaomi/sm8250/arch/arm64/configs/vendor/kona-perf_defconfig"
kernel_uvc="$lineage_root/kernel/xiaomi/sm8250/drivers/usb/gadget/function/uvc_video.c"
kernel_uac2="$lineage_root/kernel/xiaomi/sm8250/drivers/usb/gadget/function/f_uac2.c"
kernel_uac2_pcm="$lineage_root/kernel/xiaomi/sm8250/drivers/usb/gadget/function/u_audio.c"
usb_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
webcam_dir="$lineage_root/packages/services/DeviceAsWebcam"
webcam_manifest="$webcam_dir/impl/AndroidManifest.xml"
webcam_service="$webcam_dir/interface/src/com/android/deviceaswebcam/DeviceAsWebcamFgService.java"
webcam_audio="$webcam_dir/interface/src/com/android/deviceaswebcam/UsbAudioBridge.java"
webcam_audio_native="$webcam_dir/interface/jni/UsbAudioBridge.cpp"
webcam_preview="$webcam_dir/impl/src/com/android/deviceaswebcam/DeviceAsWebcamPreview.java"
settings_controller="$lineage_root/packages/apps/Settings/src/com/android/settings/homepage/CaCamOsWebcamPreferenceController.java"

for required in \
    "$device_mk" "$device_product" "$device_variant" "$device_releasetools" \
    "$framework_overlay" "$kernel_config" \
    "$kernel_uvc" "$kernel_uac2" "$kernel_uac2_pcm" "$usb_hal" "$webcam_manifest" \
    "$webcam_service" "$webcam_audio" "$webcam_audio_native" "$webcam_preview" \
    "$settings_controller"; do
    [[ -f "$required" ]] || fail "missing $required"
done

grep -q '^CACAMOS_APPLIANCE := true$' "$device_product" ||
    fail "cmi is not configured as a dedicated CaCamOS appliance"
grep -q "ro.cacamos.version=$cacamos_version" "$device_product" ||
    fail "cmi does not expose CaCamOS version $cacamos_version"
grep -q 'ro.cacamos.appliance=true' "$device_product" ||
    fail "cmi appliance property is missing"
grep -q '\.brand = "CaCamOS"' "$device_variant" &&
    grep -q '\.model = "CaCamOS Mi 10 Pro Webcam"' "$device_variant" ||
    fail "cmi runtime identity is not branded as CaCamOS"
grep -q 'AddImage(info, "recovery.img", "/dev/block/bootdevice/by-name/recovery")' \
    "$device_releasetools" ||
    fail "cmi OTA does not install its matching CaCamOS recovery"
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
grep -q '"USB Microphone Active"' "$kernel_uac2_pcm" &&
    grep -q '"USB Speakers Active"' "$kernel_uac2_pcm" ||
    fail "UAC2 host stream activity controls are missing"
ok "sm8250 UVC and UAC2 gadget implementation"

grep -q 'linkFunction("uac2.0", i++)' "$usb_hal" ||
    fail "QTI USB HAL does not compose UAC2 with UVC"
grep -q 'CaCamOS Webcam + Audio' "$usb_hal" ||
    fail "CaCamOS composite USB identity is missing"
grep -q 'android:persistent="true"' "$webcam_manifest" ||
    fail "DeviceAsWebcam is not persistent"
grep -q 'android:directBootAware="true"' "$webcam_manifest" ||
    fail "DeviceAsWebcam is not direct-boot aware"
grep -q 'android.permission.DEVICE_POWER' "$webcam_manifest" ||
    fail "DeviceAsWebcam cannot force the display to sleep"
grep -q 'ro.cacamos.appliance' "$webcam_service" ||
    fail "DeviceAsWebcam appliance startup is missing"
grep -q 'AudioRecord.Builder()' "$webcam_audio" ||
    fail "USB microphone bridge is missing"
grep -q 'nativeIsMicrophoneActive()' "$webcam_audio" &&
    grep -q 'nativeAreSpeakersActive()' "$webcam_audio" ||
    fail "USB audio is not gated by host stream activity"
grep -q 'mixer_get_ctl_by_name' "$webcam_audio_native" ||
    fail "native USB audio cannot read host stream activity"
grep -q 'windowAttrs.userActivityTimeout = SCREEN_TIMEOUT_MS' "$webcam_preview" ||
    fail "webcam preview does not use an energy-saving screen timeout"
grep -q 'mPowerManager.goToSleep(' "$webcam_preview" ||
    fail "webcam preview does not force display sleep after inactivity"
grep -q 'public void onUserInteraction()' "$webcam_preview" ||
    fail "webcam preview does not reset its timeout after touch input"
grep -q 'postDelayed(mTurnScreenOff, SCREEN_TIMEOUT_MS)' "$webcam_preview" ||
    fail "webcam preview does not arm its explicit display timeout"
grep -q 'Settings.Secure.DOUBLE_TAP_TO_WAKE' "$webcam_preview" ||
    fail "webcam preview does not enable touch wake"
if grep -q 'FLAG_KEEP_SCREEN_ON\|setTurnScreenOn(true)' "$webcam_preview"; then
    fail "webcam preview still forces the display to remain on"
fi
grep -q 'WEBCAM_COMPONENT' "$settings_controller" ||
    fail "Settings return-to-webcam action is missing"
ok "energy-aware webcam UI, on-demand audio and maintenance navigation"

grep -q 'USB FunctionFS transport disabled by CaCamOS USB AV-only policy' \
    "$lineage_root/packages/modules/adb/daemon/main.cpp" ||
    fail "USB cable is not reserved for standard webcam/audio functions"
grep -q 'CaCamOS recovery ADB enabled for appliance maintenance' \
    "$lineage_root/bootable/recovery/recovery_main.cpp" ||
    fail "recovery ADB maintenance policy is missing"
if grep -B1 -Fq 'IsRoDebuggable() &&' \
    "$lineage_root/bootable/recovery/recovery_main.cpp"; then
    fail "recovery ADB is still disabled by non-debuggable appliance builds"
fi
grep -q 'optional /cache is unavailable; continuing installation' \
    "$lineage_root/bootable/recovery/recovery_utils/roots.cpp" ||
    fail "recovery still aborts CaCamOS updates when optional /cache is unavailable"
ok "USB AV-only policy and resilient recovery maintenance"

printf '\nPASS: CaCamOS %s source tree is complete for Xiaomi Mi 10 Pro (cmi).\n' \
    "$cacamos_version"
