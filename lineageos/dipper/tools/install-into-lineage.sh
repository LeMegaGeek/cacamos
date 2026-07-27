#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
addon_dir="$(cd "$script_dir/.." && pwd)"
patch_dir="$addon_dir/patches"

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
device_mk="$lineage_root/device/xiaomi/dipper/device.mk"
kernel_fragment="$lineage_root/kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/dipper.config"
usb_default_overlay="$lineage_root/device/xiaomi/dipper/overlay/frameworks/base/core/res/res/values/config.xml"
uvc_provider="$lineage_root/packages/services/DeviceAsWebcam/interface/jni/UVCProvider.cpp"
webcam_manifest="$lineage_root/packages/services/DeviceAsWebcam/impl/AndroidManifest.xml"
webcam_prefs="$lineage_root/packages/services/DeviceAsWebcam/impl/src/com/android/deviceaswebcam/utils/UserPrefs.java"
webcam_service="$lineage_root/packages/services/DeviceAsWebcam/interface/src/com/android/deviceaswebcam/DeviceAsWebcamFgService.java"
adbd_main="$lineage_root/packages/modules/adb/daemon/main.cpp"
wireless_debugging_enabler="$lineage_root/packages/apps/Settings/src/com/android/settings/development/WirelessDebuggingEnabler.java"

mapfile -t patch_files < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print | sort)
[[ "${#patch_files[@]}" -gt 0 ]] || fail "no addon patches found in $patch_dir"
[[ -f "$device_mk" ]] || fail "missing dipper device tree: $device_mk"
[[ -f "$kernel_fragment" ]] || fail "missing dipper kernel config: $kernel_fragment"
[[ -d "$lineage_root/packages/services/DeviceAsWebcam" ]] || fail "missing packages/services/DeviceAsWebcam; sync LineageOS lineage-22.2 first"
[[ -d "$lineage_root/packages/modules/adb" ]] || fail "missing packages/modules/adb; sync LineageOS lineage-22.2 first"
[[ -d "$lineage_root/vendor/qcom/opensource/usb" ]] || fail "missing vendor/qcom/opensource/usb; sync LineageOS lineage-22.2 first"

if grep -q 'CaCamOsDeviceAsWebcamDipper' "$device_mk" &&
    grep -q 'ro.usb.uvc.enabled=true' "$device_mk" &&
    grep -q 'ro.usb.uvc.disable_video_encode_flag=true' "$device_mk" &&
    grep -q '<bool name="config_usbDefaultToUvc">true</bool>' "$usb_default_overlay" &&
    grep -q '<bool name="config_adbWifiAutoEnable">true</bool>' "$usb_default_overlay" &&
    grep -q '<bool name="config_disableLockscreenByDefault">true</bool>' "$usb_default_overlay" &&
    grep -q 'CONFIG_USB_CONFIGFS_F_UVC=y' "$kernel_fragment" &&
    grep -q 'getFrameAndQueueBufferToGadgetDriver(true)' "$uvc_provider" &&
    grep -q 'android:directBootAware="true"' "$webcam_manifest" &&
    grep -q 'createDeviceProtectedStorageContext' "$webcam_prefs" &&
    grep -q 'launchPreview()' "$webcam_service" &&
    grep -q 'USB FunctionFS transport disabled by CaCamOS UVC-only policy' "$adbd_main" &&
    grep -q 'config_adbWifiAutoEnable' "$wireless_debugging_enabler"; then
    printf 'CaCam OS dipper webcam addon already appears to be installed.\n'
    "$script_dir/verify-patch-series.sh" --match-worktrees "$lineage_root"
    "$script_dir/verify-source-tree.sh" "$lineage_root"
    exit 0
fi

"$script_dir/verify-patch-series.sh" "$lineage_root"

printf 'Checking %d patches against %s...\n' "${#patch_files[@]}" "$lineage_root"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/cacamos-dipper-patchcheck.XXXXXX")"
trap 'rm -rf "$staging_root"' EXIT

mapfile -t touched_files < <(
    sed -n 's|^diff --git a/[^ ]* b/||p' "${patch_files[@]}" | sort -u
)
for relative_path in "${touched_files[@]}"; do
    source_path="$lineage_root/$relative_path"
    if [[ -e "$source_path" ]]; then
        staging_path="$staging_root/$relative_path"
        mkdir -p "$(dirname "$staging_path")"
        cp -a "$source_path" "$staging_path"
    fi
done

for patch_file in "${patch_files[@]}"; do
    printf '  %s\n' "$(basename "$patch_file")"
    git -C "$staging_root" apply --check "$patch_file"
    git -C "$staging_root" apply "$patch_file"
done

printf 'Applying CaCam OS dipper webcam addon...\n'
for patch_file in "${patch_files[@]}"; do
    git -C "$lineage_root" apply --check "$patch_file"
    git -C "$lineage_root" apply "$patch_file"
done

printf 'Verifying patched tree...\n'
"$script_dir/verify-source-tree.sh" "$lineage_root"

printf '\nInstalled. Next build commands:\n'
printf '  cd %s\n' "$lineage_root"
printf '  source build/envsetup.sh\n'
printf '  breakfast dipper\n'
printf '  mka bacon\n'
