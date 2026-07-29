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

require_file() {
    [[ -f "$1" ]] || fail "missing file: $1"
}

require_dir() {
    [[ -d "$1" ]] || fail "missing directory: $1"
}

require_fixed() {
    local file="$1"
    local text="$2"
    local description="$3"
    grep -Fq -- "$text" "$file" || fail "$description"
}

require_function_fixed() {
    local file="$1"
    local function="$2"
    local text="$3"
    local description="$4"
    local body

    body="$(sed -n "/^${function}(/,/^}/p" "$file")"
    [[ -n "$body" && "$body" == *"$text"* ]] || fail "$description"
}

forbid_fixed() {
    local file="$1"
    local text="$2"
    local description="$3"
    if grep -Fq -- "$text" "$file"; then
        fail "$description"
    fi
}

lineage_root="${1:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

device_mk="$lineage_root/device/xiaomi/dipper/device.mk"
device_product="$lineage_root/device/xiaomi/dipper/lineage_dipper.mk"
device_board_config="$lineage_root/device/xiaomi/dipper/BoardConfig.mk"
device_bootanimation="$lineage_root/device/xiaomi/dipper/bootanimation/bootanimation.zip"
device_init="$lineage_root/device/xiaomi/dipper/init/init.target.rc"
device_boot_probe="$lineage_root/device/xiaomi/dipper/init/cacamos_boot_probe.sh"
device_privapp_permissions="$lineage_root/device/xiaomi/dipper/permissions/privapp-permissions-cacamos.xml"
device_vendor_prop="$lineage_root/device/xiaomi/dipper/vendor.prop"
settings_defaults_overlay="$lineage_root/device/xiaomi/dipper/overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml"
kernel_base_config="$lineage_root/kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/mi845_defconfig"
kernel_device_config="$lineage_root/kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/dipper.config"
kernel_uvc_header="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/uvc.h"
kernel_uvc_function="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/f_uvc.c"
kernel_uvc_queue="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/uvc_queue.c"
kernel_uvc_video="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/uvc_video.c"
kernel_uvc_v4l2="$lineage_root/kernel/xiaomi/sdm845/drivers/usb/gadget/function/uvc_v4l2.c"
usb_gadget_hal="$lineage_root/vendor/qcom/opensource/usb/hal/UsbGadget.cpp"
usb_gadget_init="$lineage_root/vendor/qcom/opensource/usb/etc/init.qcom.usb.rc"
usb_gadget_policy="$lineage_root/system/sepolicy/private/hal_usb_gadget.te"
adbd_policy="$lineage_root/system/sepolicy/private/adbd.te"
webcam_policy="$lineage_root/system/sepolicy/private/device_as_webcam.te"
system_usb_init="$lineage_root/system/core/rootdir/init.usb.rc"
system_init="$lineage_root/system/core/rootdir/init.rc"
usb_device_manager="$lineage_root/frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
framework_usb_config="$lineage_root/frameworks/base/core/res/res/values/config.xml"
framework_manifest="$lineage_root/frameworks/base/core/res/AndroidManifest.xml"
framework_adb_service="$lineage_root/frameworks/base/services/core/java/com/android/server/adb/AdbService.java"
framework_adb_manager="$lineage_root/frameworks/base/services/core/java/com/android/server/adb/AdbDebuggingManager.java"
adbd_main="$lineage_root/packages/modules/adb/daemon/main.cpp"
settings_wireless_debugging="$lineage_root/packages/apps/Settings/src/com/android/settings/development/WirelessDebuggingEnabler.java"
settings_usb_debugging="$lineage_root/packages/apps/Settings/src/com/android/settings/development/AdbPreferenceController.java"
webcam_pkg="$lineage_root/packages/services/DeviceAsWebcam"
webcam_manifest="$webcam_pkg/impl/AndroidManifest.xml"
webcam_layout="$webcam_pkg/impl/res/layout/preview_layout.xml"
webcam_strings="$webcam_pkg/impl/res/values/strings.xml"
webcam_strings_fr="$webcam_pkg/impl/res/values-fr/strings.xml"
webcam_settings_icon="$webcam_pkg/impl/res/drawable/ic_settings.xml"
webcam_theme="$webcam_pkg/impl/res/values/themes.xml"
webcam_encoder="$webcam_pkg/interface/jni/Encoder.cpp"
webcam_buffer="$webcam_pkg/interface/jni/Buffer.cpp"
webcam_buffer_header="$webcam_pkg/interface/jni/Buffer.h"
webcam_camera="$webcam_pkg/impl/src/com/android/deviceaswebcam/CameraController.java"
webcam_controller="$webcam_pkg/impl/src/com/android/deviceaswebcam/WebcamControllerImpl.kt"
webcam_preview="$webcam_pkg/impl/src/com/android/deviceaswebcam/DeviceAsWebcamPreview.java"
webcam_rotation="$webcam_pkg/impl/src/com/android/deviceaswebcam/RotationProvider.java"
webcam_prefs="$webcam_pkg/impl/src/com/android/deviceaswebcam/utils/UserPrefs.java"
webcam_receiver="$webcam_pkg/interface/src/com/android/deviceaswebcam/DeviceAsWebcamReceiver.java"
webcam_service="$webcam_pkg/interface/src/com/android/deviceaswebcam/DeviceAsWebcamFgService.java"
webcam_sdk_provider="$webcam_pkg/interface/jni/SdkFrameProvider.cpp"
webcam_sdk_provider_header="$webcam_pkg/interface/jni/SdkFrameProvider.h"
webcam_service_manager="$webcam_pkg/interface/jni/DeviceAsWebcamServiceManager.cpp"
webcam_service_manager_header="$webcam_pkg/interface/jni/DeviceAsWebcamServiceManager.h"
uvc_provider="$webcam_pkg/interface/jni/UVCProvider.cpp"
uvc_provider_header="$webcam_pkg/interface/jni/UVCProvider.h"
overlay_dir="$lineage_root/device/xiaomi/dipper/overlay/DeviceAsWebcamCaCamOsDipper"
usb_default_overlay="$lineage_root/device/xiaomi/dipper/overlay/frameworks/base/core/res/res/values/config.xml"
lineage_common="$lineage_root/vendor/lineage/config/common.mk"
lineage_common_phone="$lineage_root/vendor/lineage/config/common_full_phone.mk"
lineage_common_mobile="$lineage_root/vendor/lineage/config/common_mobile.mk"
lineage_common_mobile_full="$lineage_root/vendor/lineage/config/common_mobile_full.mk"
build_full_base="$lineage_root/build/make/target/product/full_base.mk"
build_base_system="$lineage_root/build/make/target/product/base_system.mk"
build_default_art_config="$lineage_root/build/make/target/product/default_art_config.mk"
build_generic_system="$lineage_root/build/make/target/product/generic_system.mk"
build_handheld_product="$lineage_root/build/make/target/product/handheld_product.mk"
build_handheld_system="$lineage_root/build/make/target/product/handheld_system.mk"
build_handheld_system_ext="$lineage_root/build/make/target/product/handheld_system_ext.mk"
build_media_system="$lineage_root/build/make/target/product/media_system.mk"
build_telephony_product="$lineage_root/build/make/target/product/telephony_product.mk"
build_telephony_system="$lineage_root/build/make/target/product/telephony_system.mk"
build_telephony_system_ext="$lineage_root/build/make/target/product/telephony_system_ext.mk"
build_blueprint="$lineage_root/build/blueprint/bootstrap/command.go"
build_soong="$lineage_root/build/soong/ui/build/soong.go"
recovery_main="$lineage_root/bootable/recovery/recovery_main.cpp"
host_uvc_test="$script_dir/test-host-uvc-stream.sh"
host_uvc_reopen_test="$script_dir/test-host-uvc-reopen.sh"

for file in \
    "$device_mk" \
    "$device_product" \
    "$device_board_config" \
    "$device_bootanimation" \
    "$device_init" \
    "$device_boot_probe" \
    "$device_privapp_permissions" \
    "$device_vendor_prop" \
    "$settings_defaults_overlay" \
    "$kernel_base_config" \
    "$kernel_device_config" \
    "$kernel_uvc_header" \
    "$kernel_uvc_function" \
    "$kernel_uvc_queue" \
    "$kernel_uvc_video" \
    "$kernel_uvc_v4l2" \
    "$usb_gadget_hal" \
    "$usb_gadget_init" \
    "$usb_gadget_policy" \
    "$adbd_policy" \
    "$webcam_policy" \
    "$system_usb_init" \
    "$system_init" \
    "$usb_device_manager" \
    "$framework_usb_config" \
    "$framework_manifest" \
    "$framework_adb_service" \
    "$framework_adb_manager" \
    "$adbd_main" \
    "$settings_wireless_debugging" \
    "$settings_usb_debugging" \
    "$webcam_manifest" \
    "$webcam_layout" \
    "$webcam_strings" \
    "$webcam_strings_fr" \
    "$webcam_settings_icon" \
    "$webcam_theme" \
    "$webcam_encoder" \
    "$webcam_buffer" \
    "$webcam_buffer_header" \
    "$webcam_camera" \
    "$webcam_controller" \
    "$webcam_preview" \
    "$webcam_rotation" \
    "$webcam_prefs" \
    "$webcam_receiver" \
    "$webcam_service" \
    "$webcam_sdk_provider" \
    "$webcam_sdk_provider_header" \
    "$webcam_service_manager" \
    "$webcam_service_manager_header" \
    "$uvc_provider" \
    "$uvc_provider_header" \
    "$host_uvc_test" \
    "$host_uvc_reopen_test" \
    "$usb_default_overlay" \
    "$lineage_common" \
    "$lineage_common_phone" \
    "$lineage_common_mobile" \
    "$lineage_common_mobile_full" \
    "$build_full_base" \
    "$build_handheld_product" \
    "$build_handheld_system" \
    "$build_handheld_system_ext" \
    "$build_media_system" \
    "$build_telephony_product" \
    "$build_telephony_system" \
    "$build_telephony_system_ext" \
    "$build_blueprint" \
    "$build_soong" \
    "$recovery_main"; do
    require_file "$file"
done
require_dir "$webcam_pkg"
require_dir "$overlay_dir"

require_fixed "$build_soong" '[]string{"GOMAXPROCS", "GOMEMLIMIT"}' \
    "Soong primary builders discard the configured CPU and memory limits"
require_fixed "$build_soong" "invocationEnv[variable] = value" \
    "Soong does not forward configured Go resource limits through env -i"
require_fixed "$build_blueprint" 'os.Getenv("GOMAXPROCS") == ""' \
    "Blueprint overrides the configured GOMAXPROCS host limit"

require_fixed "$device_mk" "DeviceAsWebcam" \
    "DeviceAsWebcam is not included in dipper PRODUCT_PACKAGES"
require_fixed "$device_mk" "CaCamOsDeviceAsWebcamDipper" \
    "the dipper DeviceAsWebcam overlay is not included"
require_fixed "$device_mk" "ro.usb.uvc.enabled=true" \
    "ro.usb.uvc.enabled=true is not set"
require_fixed "$device_mk" "ro.usb.uvc.disable_video_encode_flag=true" \
    "the unsupported camera VIDEO_ENCODE flag is still enabled"
require_fixed "$device_mk" \
    'init/cacamos_boot_probe.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/cacamos_boot_probe.sh' \
    "the autonomous boot probe is not installed"
require_fixed "$device_mk" \
    'permissions/privapp-permissions-cacamos.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-cacamos.xml' \
    "the DeviceAsWebcam privileged-permission allowlist is not installed"
require_fixed "$system_init" \
    "service cacamos_boot_probe /system/bin/sh /system/bin/cacamos_boot_probe.sh" \
    "the autonomous boot probe is not started by init"
require_fixed "$device_boot_probe" "=== CACAMOS_BOOT_PROBE_TIMEOUT ===" \
    "the autonomous boot probe cannot record a failed boot"
require_fixed "$device_boot_probe" "current_functions=0x80" \
    "the boot probe does not inspect the applied UVC function"
require_fixed "$device_boot_probe" "=== CACAMOS_BOOT_PROBE_NONFATAL ===" \
    "a completed Android boot can still be forced into recovery"
require_fixed "$device_boot_probe" "reboot recovery" \
    "the autonomous boot probe cannot return a failed boot to recovery"
python3 - "$device_boot_probe" <<'PY'
import pathlib
import sys

probe = pathlib.Path(sys.argv[1]).read_text()
condition = probe.index('if [ "$(getprop sys.boot_completed)" != 1 ]')
reboot = probe.index("reboot recovery", condition)
nonfatal = probe.index("=== CACAMOS_BOOT_PROBE_NONFATAL ===", reboot)
if not condition < reboot < nonfatal:
    raise SystemExit("boot-probe recovery is not restricted to failed Android userspace")
PY
python3 - "$device_privapp_permissions" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
entries = root.findall("privapp-permissions")
if len(entries) != 1:
    raise SystemExit("CaCamOS privapp allowlist must contain one package")
entry = entries[0]
if entry.get("package") != "com.android.DeviceAsWebcam":
    raise SystemExit("CaCamOS privapp allowlist targets the wrong package")
permissions = {node.get("name") for node in entry.findall("permission")}
if permissions != {"android.permission.WRITE_SECURE_SETTINGS"}:
    raise SystemExit(f"unexpected DeviceAsWebcam privileged grants: {sorted(permissions)}")
PY
require_fixed "$device_product" "CACAMOS_APPLIANCE := true" \
    "the dedicated CaCamOS package graph is not enabled"
require_fixed "$device_product" "PRODUCT_NO_CAMERA := true" \
    "the consumer camera application is still enabled"
require_fixed "$device_product" "ro.setupwizard.mode=DISABLED" \
    "the setup wizard is not disabled"
require_fixed "$device_product" "ro.cacamos.appliance=true" \
    "the appliance runtime property is missing"
require_fixed "$device_product" "ro.cacamos.version=1.0.0" \
    "the product is not versioned as CaCamOS 1.0.0"
require_fixed "$device_product" "PRODUCT_MODEL := CaCamOS MI 8 Webcam" \
    "the Android product identity is not CaCamOS"
require_fixed "$device_product" "PRODUCT_BRAND := CaCamOS" \
    "the Android product brand is not CaCamOS"
require_fixed "$device_board_config" \
    "TARGET_BOOTANIMATION := device/xiaomi/dipper/bootanimation/bootanimation.zip" \
    "the Lineage boot animation is not replaced by CaCamOS"
require_fixed "$webcam_strings" '<string name="app_label">CaCamOS</string>' \
    "the default webcam application label is not CaCamOS"
require_fixed "$webcam_strings_fr" \
    '<string name="app_label" msgid="5357575528456632609">"CaCamOS"</string>' \
    "the French webcam application label is not CaCamOS"
python3 - "$device_bootanimation" <<'PY'
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    if archive.comment != b"CaCamOS":
        raise SystemExit("CaCamOS boot animation lacks its brand marker")
    if archive.read("desc.txt") != (
        b"1080 2248 30\n"
        b"c 1 0 part0\n"
        b"c 0 0 part1\n"
    ):
        raise SystemExit("CaCamOS boot animation has an invalid descriptor")
    frames = sorted(
        name for name in archive.namelist()
        if name.startswith("part1/") and name.endswith(".png")
    )
    if len(frames) < 16:
        raise SystemExit("CaCamOS boot animation is not smoothly animated")
    header = archive.read(frames[0])
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("CaCamOS boot animation frame is not PNG")
    if struct.unpack(">II", header[16:24]) != (1080, 2248):
        raise SystemExit("CaCamOS boot animation does not match the MI8 display")
PY
require_fixed "$device_vendor_prop" "vendor.usb.product_string=CaCamOS Webcam" \
    "the USB product identity is not CaCamOS Webcam"
require_fixed "$recovery_main" 'GetBoolProperty("ro.cacamos.appliance", false)' \
    "recovery ADB is not restricted to the CaCamOS appliance"
require_fixed "$recovery_main" 'SetProperty("ro.adb.secure.recovery", "0")' \
    "CaCamOS recovery does not authorize unattended physical-cable maintenance"
require_fixed "$recovery_main" \
    "CaCamOS recovery ADB enabled for appliance maintenance" \
    "CaCamOS recovery ADB lacks its compiled verification marker"
python3 - "$recovery_main" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
policy = text.index("CaCamOS recovery ADB enabled for appliance maintenance")
adbd_startup = text.index("// Set up adb_keys and enable root before starting ADB.")
if policy > adbd_startup:
    raise SystemExit("CaCamOS recovery ADB policy is applied after adbd startup")
PY
for file in "$lineage_common" "$lineage_common_phone" "$lineage_common_mobile" \
        "$lineage_common_mobile_full"; do
    require_fixed "$file" 'CACAMOS_APPLIANCE' \
        "Lineage package selection is not appliance-aware in $file"
done
require_fixed "$lineage_common_mobile" "LatinIME" \
    "the appliance lacks a keyboard for Wi-Fi maintenance"
require_fixed "$lineage_common_mobile" "TrebuchetOverlay" \
    "the appliance package gate no longer covers the launcher overlay"
python3 - \
    "$device_product" \
    "$device_mk" \
    "$lineage_common_mobile" \
    "$build_base_system" \
    "$build_default_art_config" \
    "$build_full_base" \
    "$build_generic_system" \
    "$build_handheld_product" \
    "$build_handheld_system" \
    "$build_handheld_system_ext" \
    "$build_telephony_product" \
    "$build_telephony_system" \
    "$build_telephony_system_ext" \
    "$build_media_system" <<'PY'
import pathlib
import re
import sys


def assert_gated(path, packages):
    lines = pathlib.Path(path).read_text().splitlines()
    gate_stack = []
    gated = set()
    ungated = set()
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("ifeq", "ifneq", "ifdef", "ifndef")):
            gate_stack.append(
                stripped == "ifneq ($(CACAMOS_APPLIANCE),true)"
            )
            continue
        if stripped == "endif":
            if not gate_stack:
                raise SystemExit(f"unbalanced endif in {path}")
            gate_stack.pop()
            continue
        for package in packages:
            if re.search(rf"(^|[\s\\]){re.escape(package)}([\s\\]|$)", line):
                if any(gate_stack):
                    gated.add(package)
                elif not stripped.startswith("#"):
                    ungated.add(package)
    missing = sorted(set(packages) - gated)
    if missing:
        raise SystemExit(
            f"{path} leaves appliance packages outside the CaCamOS gate: {missing}"
        )
    if ungated:
        raise SystemExit(
            f"{path} also includes ungated appliance packages: {sorted(ungated)}"
        )


product = pathlib.Path(sys.argv[1]).read_text()
if product.index("CACAMOS_APPLIANCE := true") > product.index(
    "$(call inherit-product, device/xiaomi/dipper/device.mk)"
):
    raise SystemExit("CACAMOS_APPLIANCE is declared after the device inheritance")

expectations = {
    sys.argv[2]: [
        "android.hardware.nfc-service.nxp",
        "com.android.nfc_extras",
        "Tag",
        "XiaomiPocketMode",
    ],
    sys.argv[3]: [
        "QuickAccessWallet",
        "ThemePicker",
        "ThemesStub",
    ],
    sys.argv[4]: [
        "com.android.nfcservices",
        "NfcNci",
    ],
    sys.argv[5]: [
        "com.android.nfcservices:framework-nfc",
    ],
    sys.argv[6]: [
        "LiveWallpapersPicker",
        "PhotoTable",
    ],
    sys.argv[7]: [
        "com.android.nfc_extras",
        "Tag",
    ],
    sys.argv[8]: [
        "Browser2",
        "Calendar",
        "Contacts",
        "DeskClock",
        "Gallery2",
        "Music",
        "QuickSearchBox",
    ],
    sys.argv[9]: [
        "BasicDreams",
        "BluetoothMidiService",
        "BuiltInPrintService",
        "DeviceDiagnostics",
        "DownloadProviderUi",
        "EasterEgg",
        "ManagedProvisioning",
        "MtpService",
        "MusicFX",
        "PrintRecommendationService",
        "PrintSpooler",
        "SimAppDialog",
        "StatementService",
    ],
    sys.argv[10]: [
        "AccessibilityMenu",
        "Launcher3QuickStep",
        "Provision",
    ],
    sys.argv[11]: [
        "Dialer",
        "ImsServiceEntitlement",
    ],
    sys.argv[12]: [
        "CarrierDefaultApp",
        "CallLogBackup",
        "com.android.cellbroadcast",
        "CellBroadcastLegacyApp",
    ],
    sys.argv[13]: ["EmergencyInfo"],
    sys.argv[14]: ["StatementService"],
}
for path, packages in expectations.items():
    assert_gated(path, packages)

base_system = pathlib.Path(sys.argv[4]).read_text()
art_config = pathlib.Path(sys.argv[5]).read_text()
for path, text, variable in (
    (sys.argv[4], base_system, "PRODUCT_PACKAGES"),
    (sys.argv[5], art_config, "PRODUCT_BOOT_JARS"),
):
    start = text.index("ifeq ($(CACAMOS_APPLIANCE),true)")
    end = text.index("endif", start)
    appliance = text[start:end]
    if variable not in appliance or "framework-nfc" not in appliance:
        raise SystemExit(
            f"{path} does not retain the NFC API jar without its appliance service"
        )
PY
ok "CaCamOS 1.0.0 identity, branded boot and dedicated package graph"

require_fixed "$usb_default_overlay" '<bool name="config_usbDefaultToUvc">true</bool>' \
    "dipper does not default USB to UVC"
require_fixed "$usb_default_overlay" '<bool name="config_adbWifiAutoEnable">true</bool>' \
    "dipper does not keep wireless debugging enabled"
require_fixed "$usb_default_overlay" '<bool name="config_disableLockscreenByDefault">true</bool>' \
    "dipper does not disable the lock screen for a fresh data partition"
for setting in def_device_provisioned def_lockscreen_disabled def_user_setup_complete; do
    require_fixed "$settings_defaults_overlay" "<bool name=\"$setting\">true</bool>" \
        "fresh CaCamOS data does not default $setting to true"
done
require_fixed "$settings_defaults_overlay" \
    '<string name="def_device_name_simple">CaCamOS Webcam</string>' \
    "the default device name is not CaCamOS Webcam"
require_fixed "$framework_usb_config" '<bool name="config_usbDefaultToUvc">false</bool>' \
    "frameworks/base lacks the UVC default resource"
require_fixed "$framework_usb_config" '<bool name="config_adbWifiAutoEnable">false</bool>' \
    "frameworks/base lacks the wireless-debugging policy resource"
require_fixed "$usb_device_manager" "return UsbManager.FUNCTION_UVC" \
    "UsbDeviceManager does not select UVC-only"
require_fixed "$usb_device_manager" "long getAppliedFunctions(long functions)" \
    "UsbDeviceManager lacks the final appliance function gate"
require_fixed "$usb_device_manager" "if (isDefaultToUvcConfigured())" \
    "UsbDeviceManager can still apply a non-UVC cable function"
require_fixed "$usb_device_manager" "prepareDeviceAsWebcamServiceIfNeeded(config)" \
    "DeviceAsWebcam is not prepared before UVC activation"
require_fixed "$adbd_main" 'GetBoolProperty("ro.usb.uvc.enabled", false)' \
    "adbd does not apply the immutable UVC-only product policy"
require_fixed "$adbd_main" "#if !defined(__ANDROID_RECOVERY__)" \
    "the UVC-only adbd policy would also disable recovery sideload"
require_fixed "$adbd_main" "USB FunctionFS transport disabled by CaCamOS UVC-only policy" \
    "adbd UVC-only cable suppression is not diagnosable"
require_fixed "$adbd_main" "generic fallback below cannot expose an unauthenticated TCP port" \
    "adbd can expose its generic TCP fallback when the USB endpoint is absent"
require_fixed "$adbd_policy" "get_prop(adbd, usb_uvc_enabled_prop)" \
    "SELinux prevents adbd from reading the immutable UVC-only product policy"
forbid_fixed "$device_init" "vendor.sys.usb.adb.disabled" \
    "the obsolete property-race workaround still exists in the device init"
ok "UVC-only cable policy and automatic startup"

require_fixed "$framework_adb_service" "WIFI_PERSISTENT_CONFIG_PROPERTY" \
    "AdbService does not persist wireless debugging"
require_fixed "$framework_adb_service" "enableAdbWifiAfterNetworkConnect" \
    "AdbService does not restore wireless debugging after Wi-Fi reconnect"
require_fixed "$framework_adb_manager" "ADB_WIFI_RETRY_INTERVAL_MS" \
    "AdbDebuggingManager does not retry wireless ADB"
require_fixed "$framework_adb_manager" \
    "sendEmptyMessageDelayed(" \
    "AdbDebuggingManager has no delayed retry scheduling"
require_fixed "$framework_adb_manager" "if (!mAutoEnableAdbWifi)" \
    "AdbDebuggingManager does not preserve the appliance policy"
require_fixed "$framework_adb_manager" "CaCamOS wireless ADB listening on port" \
    "wireless ADB startup does not expose a runtime diagnostic"
require_fixed "$settings_wireless_debugging" "shouldKeepAdbWifiEnabledWithoutNetwork" \
    "Settings still clears wireless debugging when Wi-Fi is temporarily absent"
require_fixed "$settings_usb_debugging" "isUsbAdbDisabledByProduct" \
    "Settings still exposes USB debugging on the UVC-only appliance"
ok "persistent ADB over Wi-Fi and hidden USB debugging policy"

for file in Android.bp AndroidManifest.xml \
    res/raw/physical_camera_mapping.json \
    res/raw/physical_camera_zoom_ratio_ranges.json \
    res/raw/ignored_cameras.json \
    res/raw/ignored_v4l2_nodes.json; do
    require_file "$overlay_dir/$file"
done
python3 - "$overlay_dir" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for path in sorted((root / "res/raw").glob("*.json")):
    with path.open(encoding="utf-8") as stream:
        json.load(stream)

ignored = json.loads((root / "res/raw/ignored_v4l2_nodes.json").read_text())
text = repr(ignored)
for node in ("/dev/video0", "/dev/video32"):
    if node not in text:
        raise SystemExit(f"{node} is missing from ignored_v4l2_nodes.json")
PY
ok "valid MI8 DeviceAsWebcam resource overlay"

require_fixed "$lineage_root/frameworks/base/core/java/android/hardware/usb/UsbManager.java" \
    "USB_FUNCTION_UVC" "framework UsbManager does not expose UVC"
require_fixed "$lineage_root/system/sepolicy/private/property_contexts" \
    "ro.usb.uvc.enabled" "SELinux property context for UVC is missing"
require_fixed "$lineage_root/system/sepolicy/private/system_server.te" \
    "get_prop(system_server, usb_uvc_enabled_prop)" \
    "system_server cannot read the UVC policy property"
require_fixed "$usb_gadget_hal" "GadgetFunction::UVC" \
    "QTI USB gadget HAL does not handle UVC"
require_fixed "$usb_gadget_hal" "uvc.0" \
    "QTI USB gadget HAL does not link the UVC function"
require_fixed "$usb_gadget_policy" \
    "get_prop(hal_usb_gadget_server, usb_uvc_enabled_prop)" \
    "USB gadget HAL cannot read the UVC policy property"
ok "framework, HAL and SELinux UVC path"

python3 - "$webcam_manifest" <<'PY'
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(sys.argv[1]).getroot()
requested = {
    node.get(ANDROID + "name")
    for node in root.findall("uses-permission")
}
expected = {
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.CAMERA",
    "android.permission.FOREGROUND_SERVICE_CAMERA",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.WRITE_SECURE_SETTINGS",
}
if requested != expected:
    raise SystemExit(
        "unexpected source permissions: "
        f"found={sorted(requested)}, expected={sorted(expected)}"
    )

receiver = root.find("./application/receiver")
activity = root.find("./application/activity")
service = root.find("./application/service")
application = root.find("./application")
if application is None:
    raise SystemExit("application declaration is missing")
if application.get(ANDROID + "persistent") != "true":
    raise SystemExit("DeviceAsWebcam is not a persistent appliance process")
if application.get(ANDROID + "allowBackup") != "false":
    raise SystemExit("DeviceAsWebcam appliance data can still be backed up")
for label, node in (("receiver", receiver), ("activity", activity), ("service", service)):
    if node is None or node.get(ANDROID + "directBootAware") != "true":
        raise SystemExit(f"{label} is not direct-boot aware")
if receiver.get(ANDROID + "permission") != "android.permission.MANAGE_USB":
    raise SystemExit("exported receiver is not protected by MANAGE_USB")

actions = {
    node.get(ANDROID + "name")
    for node in receiver.findall("./intent-filter/action")
}
required_actions = {
    "android.intent.action.BOOT_COMPLETED",
    "android.intent.action.MY_PACKAGE_REPLACED",
    "android.hardware.usb.action.USB_STATE",
    "com.android.DeviceAsWebcam.action.PREPARE_UVC",
}
if actions != required_actions:
    raise SystemExit(
        "unexpected receiver actions: "
        f"found={sorted(actions)}, expected={sorted(required_actions)}"
    )

activity_actions = {
    node.get(ANDROID + "name")
    for node in activity.findall("./intent-filter/action")
}
activity_categories = {
    node.get(ANDROID + "name")
    for node in activity.findall("./intent-filter/category")
}
if "android.intent.action.MAIN" not in activity_actions:
    raise SystemExit("webcam preview is not a MAIN activity")
if "android.intent.category.HOME" not in activity_categories:
    raise SystemExit("webcam preview is not the appliance HOME activity")
if activity.get(ANDROID + "launchMode") != "singleTask":
    raise SystemExit("webcam HOME activity is not singleTask")
if service.get(ANDROID + "exported") != "false":
    raise SystemExit("webcam foreground service is exported")
PY
for permission in \
    android.permission.START_ACTIVITIES_FROM_BACKGROUND \
    android.permission.START_FOREGROUND_SERVICES_FROM_BACKGROUND \
    android.permission.SYSTEM_CAMERA; do
    forbid_fixed "$webcam_manifest" "$permission" \
        "forbidden privileged permission requested: $permission"
done
require_fixed "$framework_manifest" \
    '<protected-broadcast android:name="com.android.DeviceAsWebcam.action.PREPARE_UVC" />' \
    "PREPARE_UVC is not a protected broadcast"
require_fixed "$webcam_prefs" "createDeviceProtectedStorageContext" \
    "webcam preferences are unavailable before credential unlock"
forbid_fixed "$webcam_receiver" "Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)" \
    "camera foreground service is still started before credential unlock"
require_fixed "$webcam_receiver" "userManager.isUserUnlocked()" \
    "boot broadcasts can still start the camera service before user unlock"
require_fixed "$webcam_receiver" "receiver-deferred-until-user-unlocked" \
    "deferred boot startup leaves no diagnostic"
require_fixed "$webcam_service" "Executors.newSingleThreadExecutor" \
    "UVC initialization has no dedicated worker"
require_fixed "$webcam_service" "initializeControllerAndNativeService(generation)" \
    "camera controller initialization is not supervised"
require_fixed "$webcam_service" "waiting-for-android-runtime generation=" \
    "service does not wait for user unlock and camera framework readiness"
require_fixed "$webcam_service" "cameraManager.getCameraIdList()" \
    "camera framework readiness is not checked before controller creation"
require_fixed "$webcam_service" "initializeNativeService(generation)" \
    "service does not initialize UVC asynchronously"
require_fixed "$webcam_service" "shouldStartServiceNative(ignoredNodes)" \
    "service does not wait for the UVC node before native setup"
require_fixed "$webcam_service" "if (mServiceRunning || mServiceStopping)" \
    "duplicate service starts are not guarded"
require_fixed "$webcam_service" "getMainThreadHandler().post(this::launchPreview)" \
    "webcam preview is not opened after native readiness"
require_fixed "$webcam_service" "return START_STICKY;" \
    "the webcam service is not sticky"
require_fixed "$webcam_service" "public final boolean isWebcamReady()" \
    "the preview cannot reject a half-started native service"
require_fixed "$webcam_service" "restartNativeService(generation, webcamController)" \
    "UVC disconnects do not trigger in-process recovery"
require_fixed "$webcam_service" "mNativeLifecycleLock" \
    "native setup and teardown can overlap"
forbid_fixed "$webcam_service" "stopSelf();" \
    "UVC disconnect still destroys the dedicated webcam service"
require_fixed "$webcam_service" 'SystemProperties.getBoolean("ro.cacamos.appliance", false)' \
    "appliance-only maintenance setup is not product-gated"
require_fixed "$webcam_service" "Settings.Global.DEVELOPMENT_SETTINGS_ENABLED" \
    "wireless-debugging maintenance settings remain hidden"
require_fixed "$webcam_service" "/cache/recovery/cacamos-boot-state.log" \
    "failed appliance boots leave no recovery-readable diagnostic"
require_fixed "$webcam_policy" \
    "allow device_as_webcam cache_recovery_file:file create_file_perms;" \
    "SELinux prevents recovery-readable appliance diagnostics"
require_fixed "$webcam_service_manager" "mUVCProvider.reset();" \
    "failed native UVC setup leaves a partially initialized provider"
python3 - "$webcam_service" <<'PY'
import pathlib
import sys

service = pathlib.Path(sys.argv[1]).read_text()
guard_start = service.index("if (mServiceRunning || mServiceStopping)")
guard_end = service.index("mServiceRunning = true;", guard_start)
if "launchPreview()" in service[guard_start:guard_end]:
    raise SystemExit("duplicate service starts still relaunch the webcam preview")
start = service.index("public final int onStartCommand")
end = service.index("private void launchPreview", start)
if "setupServicesAndStartListening()" in service[start:end]:
    raise SystemExit("onStartCommand still performs native UVC setup on the main thread")
if "getWebcamController(" in service[start:end]:
    raise SystemExit("onStartCommand still creates the camera controller on the main thread")
if "Thread.sleep" in service[start:end]:
    raise SystemExit("onStartCommand still waits on the main thread")
PY
require_fixed "$webcam_preview" "FLAG_KEEP_SCREEN_ON" \
    "webcam preview does not keep the appliance screen awake"
require_fixed "$webcam_preview" "startForegroundService(serviceIntent)" \
    "the HOME activity does not explicitly start the webcam service"
require_fixed "$webcam_preview" "Context.BIND_AUTO_CREATE" \
    "the HOME activity cannot bind a missing webcam service"
require_fixed "$webcam_preview" "attachPreviewIfReady()" \
    "preview attachment is not asynchronous"
require_fixed "$webcam_preview" "userManager.isUserUnlocked()" \
    "camera foreground service can start before user unlock"
require_fixed "$webcam_preview" "mAttachServiceWhenReady" \
    "the HOME activity does not wait for native UVC readiness"
forbid_fixed "$webcam_preview" "mWebcamControllerReady.block()" \
    "the webcam HOME activity can still block its main thread"
forbid_fixed "$webcam_preview" "finish();" \
    "temporary UVC unavailability still closes the appliance HOME activity"
require_fixed "$webcam_preview" "controller.hide(WindowInsets.Type.systemBars())" \
    "the appliance preview does not enter immersive mode"
require_fixed "$webcam_preview" "public void onBackPressed()" \
    "the back button can leave the appliance HOME activity"
require_fixed "$webcam_preview" "Settings.ACTION_SETTINGS" \
    "the appliance has no explicit maintenance entry point"
require_fixed "$webcam_layout" 'android:id="@+id/maintenance_button"' \
    "the maintenance control is missing from the webcam UI"
require_fixed "$webcam_theme" '<item name="android:windowFullscreen">true</item>' \
    "webcam preview theme is not fullscreen"
forbid_fixed "$webcam_preview" "setShowWhenLocked(true)" \
    "webcam preview still masks the credential screen"
forbid_fixed "$webcam_preview" "controller.show(WindowInsets.Type.systemBars())" \
    "the dedicated preview still exposes persistent system navigation"
ok "credential-safe startup, supervised service and nonblocking appliance HOME"

python3 - "$usb_gadget_init" "$uvc_provider" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
for identity in (
    'configuration "CaCamOS UVC"',
    'function_name "CaCamOS Webcam"',
):
    if identity not in text:
        raise SystemExit(f"missing dedicated USB identity: {identity}")
entries = []
for number, line in enumerate(text.splitlines(), 1):
    stripped = line.strip()
    if stripped.startswith("#") or "dwFrameInterval" not in stripped:
        continue
    value = stripped.split("dwFrameInterval", 1)[1].strip()
    entries.append((number, value))

if not entries:
    raise SystemExit("no UVC frame intervals found")
expected = r"333333\n666666\n"
bad = [(number, value) for number, value in entries if value != expected]
if bad:
    raise SystemExit(f"unexpected UVC frame intervals: {bad}")

for profile in ("mjpeg/m1/576p", "mjpeg/m/576p"):
    base = f"/config/usb_gadget/g1/functions/uvc.0/streaming/{profile}"
    required = {
        f"write {base}/wWidth 1024",
        f"write {base}/wHeight 576",
        f"write {base}/dwMinBitRate 47185920",
        f"write {base}/dwMaxBitRate 141557760",
        f"write {base}/dwMaxVideoFrameBufferSize 1179648",
    }
    missing = sorted(entry for entry in required if entry not in text)
    if missing:
        raise SystemExit(f"{profile} has invalid MJPEG descriptors: {missing}")

for prefix in ("mjpeg/m1", "mjpeg/m"):
    hd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/720p")
    middle = text.index(
        f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/576p"
    )
    if hd >= middle:
        raise SystemExit(f"{prefix} does not advertise 720p as its default frame")

for forbidden in (
    "streaming/mjpeg/m1/360p",
    "streaming/mjpeg/m/360p",
    "streaming/uncompressed/u/360p",
    "streaming/uncompressed/u1",
    "streaming/header/h1/u1",
):
    if forbidden in text:
        raise SystemExit(f"obsolete 360p/raw high-speed mode remains: {forbidden}")

h1_mjpeg = (
    "streaming/mjpeg/m1 /config/usb_gadget/g1/functions/uvc.0/"
    "streaming/header/h1/m1"
)
if h1_mjpeg not in text:
    raise SystemExit("high-speed UVC header does not expose MJPEG")

h_mjpeg = text.index(
    "streaming/mjpeg/m /config/usb_gadget/g1/functions/uvc.0/streaming/header/h/m"
)
h_raw = text.index(
    "streaming/uncompressed/u /config/usb_gadget/g1/functions/uvc.0/streaming/header/h/u"
)
if h_mjpeg >= h_raw:
    raise SystemExit("super-speed UVC header does not default to MJPEG")

provider = pathlib.Path(sys.argv[2]).read_text()
start = provider.index("static ConfigFrame makeConfigFrame")
end = provider.index("std::vector<ConfigFormat> UVCProvider::UVCDevice::getFormats", start)
fallback = provider[start:end]
for required in ("333333", "666666"):
    if required not in fallback:
        raise SystemExit(f"fallback interval {required} is missing")
for forbidden in ("166666", "1000000", "5000000"):
    if forbidden in fallback:
        raise SystemExit(f"unsupported fallback interval {forbidden} is advertised")
if "/*width*/ 640, /*height*/ 360" in fallback:
    raise SystemExit("obsolete 360p fallback UVC mode remains")
if fallback.index("/*width*/ 1280, /*height*/ 720") >= fallback.index(
        "/*width*/ 1024, /*height*/ 576"):
    raise SystemExit("fallback UVC modes do not default to 1280x720")
if "/*width*/ 1920, /*height*/ 1080" not in fallback:
    raise SystemExit("1920x1080 fallback UVC mode is missing")
if "return {mjpeg};" not in fallback or "ConfigFormat yuyv" in fallback:
    raise SystemExit("high-speed fallback UVC modes are not MJPEG-only")
PY
ok "standard MJPEG 1280x720, 1024x576 and 1920x1080 modes at 30 and 15 FPS"

require_fixed "$uvc_provider" "VIDIOC_S_PARM" \
    "DeviceAsWebcam does not pass the negotiated frame interval to the kernel"

require_fixed "$uvc_provider" "getFrameAndQueueBufferToGadgetDriver(true)" \
    "the first-buffer UVC startup path is missing"
require_fixed "$webcam_encoder" "Status Encoder::encodeWarmupFrame" \
    "the UVC startup path has no synchronous MJPEG warmup encoder"
require_fixed "$webcam_encoder" "memset(mI420.y.get(), 16, lumaPixels)" \
    "the MJPEG warmup frame does not initialize its luma plane"
require_fixed "$webcam_encoder" "memset(mI420.u.get(), 128, chromaPixels)" \
    "the MJPEG warmup frame does not initialize its chroma planes"
require_fixed "$webcam_sdk_provider" "Status SdkFrameProvider::queueWarmupFrame()" \
    "the frame provider cannot preload the first UVC frame"
require_fixed "$webcam_sdk_provider" "producerBuffer->setTimestamp(1)" \
    "the warmup frame cannot be selected by the latest-frame buffer logic"
require_fixed "$webcam_sdk_provider" "mBufferProducer->queueFilledBuffer(producerBuffer)" \
    "the encoded warmup frame is not returned to the UVC consumer"
require_fixed "$uvc_provider" "frameProvider->queueWarmupFrame()" \
    "UVC startup does not preload a valid frame before starting the camera"
require_fixed "$webcam_buffer" "mProducerBufferFilled.wait_until(l, deadline)" \
    "encoded-frame waits are not bounded"
require_fixed "$webcam_buffer_header" "mConsumerBufferHasFrame = false" \
    "the last valid webcam frame cannot be retained"
require_fixed "$webcam_buffer" "reuseCurrentBufferOnTimeout && mConsumerBufferHasFrame" \
    "a temporary camera-frame gap can still starve the UVC endpoint"
require_fixed "$uvc_provider" \
    "const auto frameWait = std::chrono::milliseconds((1000 + fps - 1) / fps)" \
    "normal UVC buffer circulation is not paced at the negotiated frame rate"
require_fixed "$webcam_buffer" \
    "getFilledBufferAndSwap(5s, /*reuseCurrentBufferOnTimeout*/ false)" \
    "the default encoded-frame wait is not bounded"
require_fixed "$uvc_provider" \
    "constexpr auto FIRST_FRAME_WAIT = std::chrono::milliseconds(12'000)" \
    "the first encoded frame does not have a bounded camera-startup allowance"
require_fixed "$uvc_provider" \
    "FIRST_FRAME_WAIT, /*reuseCurrentBufferOnTimeout*/ false" \
    "the first encoded frame does not use the camera-startup allowance"
require_fixed "$uvc_provider" "frameWait, /*reuseCurrentBufferOnTimeout*/ true" \
    "normal UVC buffer circulation does not repeat the last valid frame"
forbid_fixed "$uvc_provider" "std::chrono::milliseconds::zero()" \
    "zero-timeout UVC buffer reuse can flood the host with duplicate frames"
require_fixed "$uvc_provider" "parent->watchControlEvents()" \
    "a failed stream cannot return to control-event polling"
require_fixed "$uvc_provider" "errno == EAGAIN || errno == EINTR" \
    "transient DQBUF errors are not separated from fatal failures"
require_fixed "$uvc_provider_header" "ENDPOINT_STOPPED" \
    "expected host endpoint shutdowns cannot be separated from frame failures"
require_fixed "$uvc_provider" "errno == ENODEV || errno == ESHUTDOWN" \
    "host USB reset is still treated as a camera frame failure"
require_fixed "$uvc_provider" \
    "Host stopped the UVC endpoint; shutting down the current stream" \
    "expected host endpoint shutdown lacks a clean runtime diagnostic"
require_fixed "$uvc_provider" "inotify_init1(IN_NONBLOCK | IN_CLOEXEC)" \
    "V4L2 node monitoring can block native service shutdown"
require_fixed "$uvc_provider" "O_RDWR | O_NONBLOCK | O_CLOEXEC" \
    "the UVC event queue is not opened in nonblocking mode"
require_fixed "$uvc_provider" "EPOLL_CTL_DEL" \
    "the MI8 UVC poll registration is not refreshed before changing masks"
require_fixed "$uvc_provider" "EPOLL_CTL_ADD" \
    "the MI8 UVC poll registration is not rearmed after changing masks"
require_fixed "$uvc_provider" "bool UVCProvider::processUVCEvent()" \
    "UVC event draining cannot distinguish an empty queue"
require_fixed "$uvc_provider" "while (processUVCEvent())" \
    "back-to-back UVC control events are not drained in one wake-up"
require_fixed "$uvc_provider" "errno == EWOULDBLOCK || errno == ENOENT" \
    "the MI8 empty V4L2 event queue is still logged as a native error"
require_fixed "$uvc_provider" "Release the delayed SET_INTERFACE status" \
    "failed native stream initialization can leave the USB host request pending"
python3 - "$uvc_provider" <<'PY'
import pathlib
import sys

provider = pathlib.Path(sys.argv[1]).read_text()
start = provider.index("Status EpollW::modify")
end = provider.index("Status EpollW::remove", start)
modify = provider[start:end]
if "EPOLL_CTL_DEL" not in modify or "EPOLL_CTL_ADD" not in modify:
    raise SystemExit("EpollW::modify does not fully rearm the MI8 UVC poll registration")
if "EPOLL_CTL_MOD" in modify:
    raise SystemExit("EpollW::modify still uses the MI8 one-frame EPOLL_CTL_MOD path")

start = provider.index("void UVCProvider::ListenToUVCFds")
end = provider.index("bool UVCProvider::processINotifyEvent", start)
listener = provider[start:end]
if listener.count("while (processUVCEvent())") < 2:
    raise SystemExit("the MI8 lost-EPOLLPRI fallback does not drain pending control events")
if "mListenToUVCFds.load() && mUVCDevice != nullptr" not in listener:
    raise SystemExit("the periodic UVC event drain is not guarded during listener shutdown")
PY
require_fixed "$host_uvc_reopen_test" "RAPID_REOPEN_ATTEMPTS" \
    "rapid host reopen regression coverage is missing"
require_fixed "$host_uvc_reopen_test" '--stream-count="$frames"' \
    "rapid host reopen test does not consume real webcam frames"
require_fixed "$host_uvc_reopen_test" "PASS: rapid close/reopen" \
    "rapid host reopen test lacks an explicit success result"
python3 - "$uvc_provider" <<'PY'
import pathlib
import sys

provider = pathlib.Path(sys.argv[1]).read_text()
start = provider.index("getFrameAndQueueBufferToGadgetDriver(bool firstBuffer)")
end = provider.index(
    "void UVCProvider::UVCDevice::processStreamOffEvent", start
)
startup = provider[start:end]
first_frame = startup.index("FIRST_FRAME_WAIT")
queue = startup.index("VIDIOC_QBUF", first_frame)
streamon = startup.index("VIDIOC_STREAMON", queue)
if not first_frame < queue < streamon:
    raise SystemExit(
        "UVC startup does not queue its warmup frame before completing SET_INTERFACE"
    )

start = provider.index("void UVCProvider::UVCDevice::processStreamOnEvent")
end = provider.index("UVCProvider::~UVCProvider", start)
stream_start = provider[start:end]
warmup = stream_start.index("queueWarmupFrame")
camera = stream_start.index("startStreaming", warmup)
first_buffer = stream_start.index("getFrameAndQueueBufferToGadgetDriver(true)", camera)
if not warmup < camera < first_buffer:
    raise SystemExit(
        "UVC startup does not prepare its warmup frame before camera and USB streaming"
    )
PY
ok "valid MJPEG warmup frame is queued before UVC SET_INTERFACE completes"
require_fixed "$webcam_camera" "CAMERA_OPERATION_TIMEOUT_MS = 5000" \
    "camera operations are not bounded"
require_fixed "$webcam_camera" "mCameraOperationGeneration" \
    "stale camera callbacks are not rejected"
require_fixed "$webcam_camera" "mCaptureSessionGeneration" \
    "stale capture-session callbacks are not rejected"
require_fixed "$webcam_camera" \
    "executeServiceEvent(() -> setWebcamStreamConfigNoOffload(width, height, fps))" \
    "camera stream reconfiguration is not serialized with stop and restart operations"
require_fixed "$webcam_sdk_provider" "mBufferProducer->cancelBuffer(producerBuffer)" \
    "failed encoded buffers are not returned to the pool"
require_fixed "$webcam_sdk_provider_header" "std::atomic<bool> mStreaming = false;" \
    "camera stream shutdown is not idempotent"
require_fixed "$webcam_sdk_provider" "mStreaming.exchange(false)" \
    "duplicate camera stream stops are not suppressed"
ok "bounded stream, camera and buffer recovery"

require_fixed "$webcam_service_manager" "provider = std::move(mUVCProvider);" \
    "native service shutdown does not move provider ownership out of the manager lock"
require_fixed "$webcam_service_manager" "mServiceStopping = true;" \
    "native service shutdown is not protected against overlapping starts"
require_fixed "$webcam_service_manager" "env->NewLocalRef(mJavaService)" \
    "Java stop requests do not retain a race-free local service reference"
forbid_fixed "$webcam_service_manager" "mJniThread" \
    "the JNI stop thread can still deadlock against Java Service.onDestroy"
forbid_fixed "$webcam_service_manager" "mUVCProvider = nullptr" \
    "UVCProvider is still destroyed while the manager lock is held"
require_fixed "$uvc_provider_header" "std::atomic<bool> mListenToUVCFds = false;" \
    "the UVC listener state is not an initially-stopped atomic"
require_fixed "$uvc_provider_header" "~UVCDevice() override;" \
    "UVCDevice does not own ordered stream and V4L2 cleanup"
require_fixed "$uvc_provider" "UVCProvider::UVCDevice::~UVCDevice()" \
    "UVCDevice ordered destruction is missing"
require_fixed "$uvc_provider" "stopAndWaitForUVCListenerThread();" \
    "UVC provider destruction does not stop its listener first"
forbid_fixed "$uvc_provider" "mUVCDevice = nullptr" \
    "the listener still clears mUVCDevice concurrently with frame callbacks"
ok "deadlock-free native service, listener and buffer lifecycle"

require_fixed "$webcam_service" "Keep the Java controller available while" \
    "Java service teardown does not preserve native buffer returns"
require_fixed "$webcam_camera" "public void shutdown()" \
    "camera controller has no permanent shutdown path"
require_fixed "$webcam_camera" "unregisterAvailabilityCallback" \
    "camera availability callback is not unregistered"
require_fixed "$webcam_camera" "mImageReaderThread.quitSafely()" \
    "ImageReader thread is not stopped"
require_fixed "$webcam_camera" "closeOutstandingImages()" \
    "outstanding camera images are not closed"
require_fixed "$webcam_camera" "releasePreviewSurfaceLocked()" \
    "preview surfaces are not released on pause or shutdown"
require_fixed "$webcam_camera" "shouldQueueWebcamFrameLocked(ts)" \
    "negotiated frame rates below the camera cadence are not enforced"
require_fixed "$webcam_camera" "mNextWebcamFrameTimestampNs += periods * intervalNs;" \
    "the webcam frame-rate limiter has no drift-resistant deadline"
require_fixed "$webcam_camera" "ImageReader returned an image without a hardware buffer" \
    "null ImageReader hardware buffers are not rejected safely"
require_fixed "$webcam_camera" "setImageFormat(ImageFormat.YUV_420_888)" \
    "the webcam ImageReader leaves its YUV dataspace undefined for legacy camera HALs"
forbid_fixed "$webcam_camera" \
    "setDefaultHardwareBufferFormat(HardwareBuffer.YCBCR_420_888)" \
    "the webcam ImageReader still uses an undefined dataspace that can stall legacy camera HALs"
for thread in CaCamFrameRead CaCamCallbacks CaCamSvcEvents; do
    require_fixed "$webcam_camera" "$thread" \
        "camera lifecycle thread $thread is not named for runtime leak detection"
done
require_fixed "$webcam_rotation" "public void clearListeners()" \
    "orientation listeners cannot be released"
require_fixed "$webcam_controller" "mCameraController.shutdown()" \
    "WebcamController does not shut down its camera controller"
require_fixed "$webcam_controller" "override fun onServiceStopRequested()" \
    "WebcamController cannot release the bound preview before service stop"
require_fixed "$webcam_service" "webcamController.onServiceStopRequested()" \
    "foreground service stop can remain blocked by its bound preview"
forbid_fixed "$webcam_camera" "mServiceEventsExecutor.execute" \
    "camera operations can still be queued after controller shutdown"
python3 - "$webcam_service" "$webcam_service_manager" <<'PY'
import pathlib
import sys

service = pathlib.Path(sys.argv[1]).read_text()
service_destroy = service[
    service.index("public void onDestroy()"):
    service.index("private void updateNotification", service.index("public void onDestroy()"))
]
service_order = (
    service_destroy.index("mServiceStopping = true"),
    service_destroy.index("nativeOnDestroy()"),
    service_destroy.index("webcamController.onDestroy()"),
    service_destroy.index("mServiceRunning = false"),
)
if tuple(sorted(service_order)) != service_order:
    raise SystemExit(
        "Java service teardown is not ordered native drain then camera cleanup"
    )

restart = service[
    service.index("private void restartNativeService"):
    service.index("@UsedByNative", service.index("private void restartNativeService"))
]
restart_order = (
    restart.index("webcamController.onServiceStopRequested()"),
    restart.index("nativeOnDestroy()"),
    restart.index("webcamController.onDestroy()"),
    restart.index("mWebcamController = null"),
    restart.index("initializeControllerAndNativeService(generation)"),
)
if tuple(sorted(restart_order)) != restart_order:
    raise SystemExit(
        "in-process UVC recovery does not detach, drain, clear, then restart"
    )
if "getWebcamController(mContext)" in restart:
    raise SystemExit(
        "in-process UVC recovery bypasses the supervised controller retry path"
    )
for marker in (
    "controller-stop-failed generation=",
    "controller-destroy-failed generation=",
):
    if marker not in restart:
        raise SystemExit(f"in-process UVC recovery lacks diagnostic marker {marker}")

manager = pathlib.Path(sys.argv[2]).read_text()
manager_destroy = manager[
    manager.index("void DeviceAsWebcamServiceManager::onDestroy()"):
    manager.index("}  // namespace webcam")
]
manager_order = (
    manager_destroy.index("mServiceStopping = true"),
    manager_destroy.index("provider.reset()"),
    manager_destroy.index("mServiceRunning = false"),
    manager_destroy.index("DeleteGlobalRef"),
)
if tuple(sorted(manager_order)) != manager_order:
    raise SystemExit("native service teardown does not drain before releasing Java state")
PY
ok "two-phase native drain and complete Java camera teardown"

require_fixed "$webcam_encoder" "Android420ToI420Rotate" \
    "Android 4:2:0 planes are not converted with their real layout"
require_fixed "$webcam_encoder" "libyuv::I420Scale" \
    "portrait output is not scaled into the fixed UVC canvas"
require_fixed "$webcam_encoder" "mI420.yRowStride = mConfig.width;" \
    "output strides are not restored before letterboxing"
require_fixed "$webcam_encoder" "setjmp(jErr.jumpBuffer)" \
    "libjpeg fatal errors are not contained"
require_fixed "$webcam_encoder" "ERREXIT(compressor, JERR_BUFFER_SIZE)" \
    "JPEG output overflow is not rejected"
require_fixed "$webcam_encoder" "dmgr.buffer[0] != 0xff" \
    "JPEG SOI/EOI markers are not validated"
require_fixed "$webcam_preview" \
    "rotation = (rotation - sensorOrientation + 360) % 360;" \
    "camera UI rotation is incorrect"
require_fixed "$webcam_rotation" \
    "return (mSensorOrientation - deviceOrientation + 360) % 360;" \
    "front-camera stream rotation is incorrect"
require_fixed "$webcam_rotation" \
    "return (mSensorOrientation + deviceOrientation) % 360;" \
    "rear-camera stream rotation is incorrect"
python3 - "$webcam_rotation" "$webcam_preview" "$uvc_provider" <<'PY'
import pathlib
import sys

rotation = pathlib.Path(sys.argv[1]).read_text()
preview = pathlib.Path(sys.argv[2]).read_text()
uvc = pathlib.Path(sys.argv[3]).read_text()

front_start = rotation.index(
    "if (mLensFacing == CameraCharacteristics.LENS_FACING_FRONT)"
)
front_end = rotation.index("\n            }", front_start)
front = rotation[front_start:front_end]
if "mSensorOrientation - deviceOrientation + 360" not in front:
    raise SystemExit("front-camera landscape stream rotation is not corrected")

ui_start = preview.index("private int calculateUiRotation")
ui_end = preview.index("return rotation <= 180", ui_start)
ui = preview[ui_start:ui_end]
if "sensorOrientation - rotation + 360" not in ui:
    raise SystemExit("rear-camera UI controls do not follow the physical phone orientation")
if "rotation - sensorOrientation + 360" not in ui:
    raise SystemExit("front-camera UI controls do not follow the physical phone orientation")

disconnect_start = uvc.index("case UVC_EVENT_DISCONNECT:")
disconnect_end = uvc.index("case UVC_EVENT_SETUP:", disconnect_start)
disconnect = uvc[disconnect_start:disconnect_end]
for required in ("processStreamOffEvent()", "watchControlEvents()"):
    if required not in disconnect:
        raise SystemExit(f"UVC reconnect path lacks {required}")
if "stopService()" in disconnect:
    raise SystemExit("physical USB disconnect still kills the persistent UVC listener")
PY
ok "stride-aware color conversion, JPEG validation and four-way rotation"

require_fixed "$host_uvc_test" 'MIN_FPS_RATIO:-0.90' \
    "host UVC test accepts a stream more than 10 percent below its negotiated rate"
require_fixed "$host_uvc_test" 'MAX_FPS_RATIO:-1.10' \
    "host UVC test accepts a stream more than 10 percent above its negotiated rate"
ok "strict host frame-rate acceptance window"

require_fixed "$kernel_device_config" "CONFIG_USB_CONFIGFS_F_UVC=y" \
    "dipper kernel config lacks CONFIG_USB_CONFIGFS_F_UVC=y"
for option in CONFIG_USB_GADGET=y CONFIG_USB_CONFIGFS=y CONFIG_MEDIA_SUPPORT=y; do
    require_fixed "$kernel_base_config" "$option" \
        "mi845 base kernel config lacks $option"
done
grep -Eq '^#define[[:space:]]+UVC_NUM_REQUESTS[[:space:]]+640$' "$kernel_uvc_header" ||
    fail "UVC request pool cannot cover a complete 15 FPS frame period"
grep -Eq '^#define[[:space:]]+UVCG_REQ_MAX_ZERO_COUNT[[:space:]]+32$' \
    "$kernel_uvc_header" ||
    fail "UVC empty bridge is not capped at 32 requests"
grep -Eq '^#define[[:space:]]+UVCG_REQ_MAX_INFLIGHT[[:space:]]+64$' \
    "$kernel_uvc_header" ||
    fail "UVC endpoint queue is not capped at the MI8-qualified 64 requests"
require_fixed "$kernel_uvc_header" "struct kthread_worker *kworker;" \
    "UVC endpoint submission has no dedicated kernel worker"
require_fixed "$kernel_uvc_header" "atomic_t queued;" \
    "UVC endpoint queue depth is not tracked"
require_fixed "$kernel_uvc_function" "uvc_function_setup_continue" \
    "SET_INTERFACE completion is not synchronized with userspace"
require_fixed "$kernel_uvc_function" "uvc->video.max_req_size" \
    "UVC request sizing does not use the negotiated endpoint capacity"
require_fixed "$kernel_uvc_function" "uvcg_video_prep_requests(&uvc->video)" \
    "UVC frame-period requests are not prepared before STREAMON"
require_fixed "$kernel_uvc_header" "UVC_DELAYED_STATUS_STREAM_ON" \
    "SET_INTERFACE delayed-status state is not tracked"
require_fixed "$kernel_uvc_v4l2" "atomic_xchg(&uvc->delayed_status" \
    "failed stream starts cannot release delayed SET_INTERFACE status"
require_fixed "$kernel_uvc_v4l2" "atomic_cmpxchg(&uvc->delayed_status" \
    "old STREAMOFF teardown can still consume a newer STREAMON acknowledgement"
python3 - "$kernel_uvc_function" "$kernel_uvc_v4l2" <<'PY'
import pathlib
import sys

function = pathlib.Path(sys.argv[1]).read_text()
case0_start = function.index("case 0:", function.index("uvc_function_set_alt"))
case1_start = function.index("case 1:", case0_start)
case0 = function[case0_start:case1_start]
for required in (
    "usb_ep_disable(uvc->video.ep)",
    "UVC_EVENT_STREAMOFF",
    "uvc->state = UVC_STATE_CONNECTED",
    "return 0",
):
    if required not in case0:
        raise SystemExit(f"nonblocking UVC alt-0 teardown lacks {required}")
if "USB_GADGET_DELAYED_STATUS" in case0 or "UVC_DELAYED_STATUS_STREAM_OFF" in case0:
    raise SystemExit("UVC alt 0 still delays ep0 and can block a rapid host reopen")

v4l2 = pathlib.Path(sys.argv[2]).read_text()
start = v4l2.index("uvc_v4l2_streamoff")
end = v4l2.index("static int", start + len("uvc_v4l2_streamoff"))
streamoff = v4l2[start:end]
if "UVC_DELAYED_STATUS_STREAM_OFF" not in streamoff:
    raise SystemExit("STREAMOFF no longer uses a typed delayed-status compare")
if "delayed_status == UVC_DELAYED_STATUS_STREAM_OFF" not in streamoff:
    raise SystemExit("STREAMOFF can acknowledge a newer STREAMON request")
PY
require_fixed "$kernel_uvc_v4l2" ".vidioc_s_parm = uvc_v4l2_set_streamparm" \
    "the UVC gadget cannot receive the negotiated frame interval"
require_fixed "$kernel_uvc_video" \
    "interval_duration = 1U << (binterval - 1);" \
    "UVC request cadence does not honor the endpoint interval"
require_fixed "$kernel_uvc_video" "video->reqs_per_frame = nreq;" \
    "UVC requests are not distributed across the complete frame period"
require_fixed "$kernel_uvc_queue" \
    "buf->req_payload_size = video->req_size;" \
    "MJPEG payload is not sent before its frame-period padding"
require_function_fixed "$kernel_uvc_video" "uvc_video_encode_isoc" \
    "int len = buf->req_payload_size;" \
    "isochronous encoding ignores the selected payload size"
require_fixed "$kernel_uvc_header" "unsigned int frame_padding;" \
    "UVC frame-period padding state is missing"
require_fixed "$kernel_uvc_video" "video->frame_padding =" \
    "UVC frame-period padding is never scheduled"
require_fixed "$kernel_uvc_video" "video->reqs_per_frame -" \
    "UVC frames do not reserve the remainder of their negotiated period"
require_fixed "$webcam_camera" "chooseWebcamCaptureSize" \
    "unsupported UVC dimensions are passed directly to the camera HAL"
require_fixed "$webcam_encoder" "ensureI420Capacity" \
    "camera fallback frames cannot be safely scaled to the negotiated UVC size"
require_fixed "$kernel_uvc_video" "kthread_create_worker(0, \"UVCG\")" \
    "UVC endpoint submission worker is missing"
require_fixed "$kernel_uvc_video" \
    "sched_setscheduler_nocheck(video->kworker->task, SCHED_FIFO," \
    "UVC endpoint submission worker is not real-time prioritized"
require_fixed "$kernel_uvc_video" "uvcg_video_hw_submit" \
    "encoded UVC requests have no hardware submission stage"
require_fixed "$kernel_uvc_video" \
    "atomic_read(&video->queued) >= UVCG_REQ_MAX_INFLIGHT" \
    "UVC endpoint queue depth is not capped before hardware submission"
require_fixed "$kernel_uvc_video" \
    "UVCG_REQ_MAX_ZERO_COUNT" \
    "UVC empty bridge depth is not capped before hardware submission"
require_fixed "$kernel_uvc_video" "req->no_interrupt = 0;" \
    "UVC requests can be stranded without completion interrupts"
forbid_fixed "$kernel_uvc_video" "req->no_interrupt = 1;" \
    "sdm845-incompatible UVC completion suppression is enabled"
require_fixed "$kernel_uvc_video" "kthread_cancel_work_sync(&video->hw_submit)" \
    "UVC hardware submission is not drained during shutdown"
require_fixed "$kernel_uvc_video" "kthread_destroy_worker(video->kworker)" \
    "UVC hardware worker is leaked during gadget teardown"
forbid_fixed "$kernel_uvc_video" "uvc_video_queue_initial_requests" \
    "legacy zero-request priming remains in the UVC path"
require_fixed "$kernel_uvc_video" "case -EXDEV:" \
    "missed isochronous transfers are not recovered"
require_fixed "$kernel_uvc_video" "UVC_STREAM_ERR" \
    "damaged UVC frames are not marked for host-side rejection"
require_fixed "$kernel_uvc_header" "struct uvc_buffer *last_buf;" \
    "USB requests do not retain ownership of their final V4L2 buffer"
require_fixed "$kernel_uvc_video" "ureq->last_buf = buf;" \
    "encoded V4L2 buffers are not tied to their final USB request"
require_fixed "$kernel_uvc_video" "last_buf = ureq->last_buf;" \
    "USB completion does not recover the request's final V4L2 buffer"
require_fixed "$kernel_uvc_video" "uvcg_complete_buffer(queue, last_buf);" \
    "V4L2 buffers are not returned from USB completion"
require_fixed "$kernel_uvc_queue" "void uvcg_complete_buffer" \
    "the UVC queue has no delayed buffer-completion path"
forbid_fixed "$kernel_uvc_video" "uvcg_queue_next_buffer(&video->queue, buf)" \
    "V4L2 buffers are still returned before USB transfer completion"
forbid_fixed "$kernel_uvc_video" "uvc_video_abort_frame" \
    "the freeze-inducing synthetic frame abort remains"
forbid_fixed "$kernel_uvc_video" "drop_incomplete_frame" \
    "encoded requests can still be discarded after transient back-pressure"
require_fixed "$kernel_uvc_video" "A terminal completion must never be resubmitted" \
    "terminal USB completions can still be resubmitted"
python3 - "$kernel_uvc_video" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
start = text.index("uvc_video_complete(struct usb_ep")
end = text.index("static void uvcg_video_hw_submit", start)
completion = text[start:end]
if "uvcg_video_ep_queue" in completion or "usb_ep_queue" in completion:
    raise SystemExit("USB requests are still submitted from completion/interrupt context")
PY
require_fixed "$kernel_uvc_video" 'alloc_workqueue("uvcgadget"' \
    "UVC request preparation has no dedicated workqueue"
require_fixed "$kernel_uvc_video" "WQ_UNBOUND | WQ_HIGHPRI" \
    "the UVC workqueue is not unbound and high priority"
require_fixed "$kernel_uvc_video" "queue_work(video->async_wq, &video->pump)" \
    "UVC completion does not wake the dedicated request pump"
require_fixed "$kernel_uvc_v4l2" "queue_work(video->async_wq, &video->pump)" \
    "V4L2 queueing does not wake the high-priority UVC pump"
forbid_fixed "$kernel_uvc_video" "schedule_work(&video->pump)" \
    "generic workqueue scheduling remains in the UVC video path"
ok "frame-paced UVC scheduler, bounded DWC3 queue and shutdown drain"

printf '\nPASS: CaCamOS source tree satisfies the static pre-build gates.\n'
printf 'Runtime WebRTC, VLC, OBS and UVC endurance validation is still required after installation.\n'
