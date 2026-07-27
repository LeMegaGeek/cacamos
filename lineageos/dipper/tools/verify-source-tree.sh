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
device_init="$lineage_root/device/xiaomi/dipper/init/init.target.rc"
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
system_usb_init="$lineage_root/system/core/rootdir/init.usb.rc"
usb_device_manager="$lineage_root/frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
framework_usb_config="$lineage_root/frameworks/base/core/res/res/values/config.xml"
framework_manifest="$lineage_root/frameworks/base/core/res/AndroidManifest.xml"
framework_adb_service="$lineage_root/frameworks/base/services/core/java/com/android/server/adb/AdbService.java"
framework_adb_manager="$lineage_root/frameworks/base/services/core/java/com/android/server/adb/AdbDebuggingManager.java"
adbd_main="$lineage_root/packages/modules/adb/daemon/main.cpp"
settings_wireless_debugging="$lineage_root/packages/apps/Settings/src/com/android/settings/development/WirelessDebuggingEnabler.java"
webcam_pkg="$lineage_root/packages/services/DeviceAsWebcam"
webcam_manifest="$webcam_pkg/impl/AndroidManifest.xml"
webcam_theme="$webcam_pkg/impl/res/values/themes.xml"
webcam_encoder="$webcam_pkg/interface/jni/Encoder.cpp"
webcam_buffer="$webcam_pkg/interface/jni/Buffer.cpp"
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
host_uvc_test="$script_dir/test-host-uvc-stream.sh"

for file in \
    "$device_mk" \
    "$device_init" \
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
    "$system_usb_init" \
    "$usb_device_manager" \
    "$framework_usb_config" \
    "$framework_manifest" \
    "$framework_adb_service" \
    "$framework_adb_manager" \
    "$adbd_main" \
    "$settings_wireless_debugging" \
    "$webcam_manifest" \
    "$webcam_theme" \
    "$webcam_encoder" \
    "$webcam_buffer" \
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
    "$usb_default_overlay"; do
    require_file "$file"
done
require_dir "$webcam_pkg"
require_dir "$overlay_dir"

require_fixed "$device_mk" "DeviceAsWebcam" \
    "DeviceAsWebcam is not included in dipper PRODUCT_PACKAGES"
require_fixed "$device_mk" "CaCamOsDeviceAsWebcamDipper" \
    "the dipper DeviceAsWebcam overlay is not included"
require_fixed "$device_mk" "ro.usb.uvc.enabled=true" \
    "ro.usb.uvc.enabled=true is not set"
require_fixed "$device_mk" "ro.usb.uvc.disable_video_encode_flag=true" \
    "the unsupported camera VIDEO_ENCODE flag is still enabled"
ok "dipper product wiring and camera output policy"

require_fixed "$usb_default_overlay" '<bool name="config_usbDefaultToUvc">true</bool>' \
    "dipper does not default USB to UVC"
require_fixed "$usb_default_overlay" '<bool name="config_adbWifiAutoEnable">true</bool>' \
    "dipper does not keep wireless debugging enabled"
require_fixed "$usb_default_overlay" '<bool name="config_disableLockscreenByDefault">true</bool>' \
    "dipper does not disable the lock screen for a fresh data partition"
require_fixed "$framework_usb_config" '<bool name="config_usbDefaultToUvc">false</bool>' \
    "frameworks/base lacks the UVC default resource"
require_fixed "$framework_usb_config" '<bool name="config_adbWifiAutoEnable">false</bool>' \
    "frameworks/base lacks the wireless-debugging policy resource"
require_fixed "$usb_device_manager" "return UsbManager.FUNCTION_UVC" \
    "UsbDeviceManager does not select UVC-only"
require_fixed "$usb_device_manager" "return functions & ~UsbManager.FUNCTION_ADB" \
    "UsbDeviceManager can still add cable ADB to the CaCamOS composition"
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
ok "persistent ADB over Wi-Fi policy"

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
}
if requested != expected:
    raise SystemExit(
        "unexpected source permissions: "
        f"found={sorted(requested)}, expected={sorted(expected)}"
    )

receiver = root.find("./application/receiver")
activity = root.find("./application/activity")
service = root.find("./application/service")
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
    "android.intent.action.LOCKED_BOOT_COMPLETED",
    "android.hardware.usb.action.USB_STATE",
    "com.android.DeviceAsWebcam.action.PREPARE_UVC",
}
if not required_actions.issubset(actions):
    raise SystemExit(f"missing receiver actions: {sorted(required_actions - actions)}")
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
require_fixed "$webcam_receiver" "Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)" \
    "receiver does not start the service during direct boot"
require_fixed "$webcam_service" "setupServicesAndStartListeningWithRetry" \
    "service does not wait for the UVC node"
require_fixed "$webcam_service" "if (mServiceRunning || mServiceStopping)" \
    "duplicate service starts are not guarded"
require_fixed "$webcam_service" "launchPreview()" \
    "webcam preview is not opened automatically"
require_fixed "$webcam_preview" "FLAG_KEEP_SCREEN_ON" \
    "webcam preview does not keep the appliance screen awake"
require_fixed "$webcam_preview" "controller.show(WindowInsets.Type.systemBars())" \
    "webcam preview does not expose system navigation"
require_fixed "$webcam_theme" '<item name="android:windowFullscreen">false</item>' \
    "webcam preview theme remains fullscreen"
forbid_fixed "$webcam_preview" "setShowWhenLocked(true)" \
    "webcam preview still masks the credential screen"
forbid_fixed "$webcam_preview" "controller.hide(WindowInsets.Type.systemBars())" \
    "webcam preview still traps the user behind hidden system navigation"
ok "minimal boot permissions, automatic preview and usable system navigation"

python3 - "$usb_gadget_init" "$uvc_provider" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
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

for profile in ("u/360p", "u1/360p"):
    base = f"/config/usb_gadget/g1/functions/uvc.0/streaming/uncompressed/{profile}"
    required = {
        f"write {base}/wWidth 640",
        f"write {base}/wHeight 360",
        f"write {base}/dwMinBitRate 55296000",
        f"write {base}/dwMaxBitRate 110592000",
        f"write {base}/dwMaxVideoFrameBufferSize 460800",
    }
    missing = sorted(entry for entry in required if entry not in text)
    if missing:
        raise SystemExit(f"{profile} has invalid raw-video descriptors: {missing}")

for prefix in ("mjpeg/m1", "mjpeg/m"):
    hd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/720p")
    sd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/360p")
    if hd >= sd:
        raise SystemExit(f"{prefix} does not advertise 720p as its default frame")

for header, mjpeg, raw in (
    ("h1", "m1", "u1"),
    ("h", "m", "u"),
):
    mjpeg_link = text.index(
        f"streaming/mjpeg/{mjpeg} /config/usb_gadget/g1/functions/uvc.0/"
        f"streaming/header/{header}/{mjpeg}"
    )
    raw_link = text.index(
        f"streaming/uncompressed/{raw} /config/usb_gadget/g1/functions/uvc.0/"
        f"streaming/header/{header}/{raw}"
    )
    if mjpeg_link >= raw_link:
        raise SystemExit(f"{header} does not advertise MJPEG as its default format")

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
if fallback.index("/*width*/ 1280, /*height*/ 720") >= fallback.index(
        "/*width*/ 640, /*height*/ 360"):
    raise SystemExit("fallback UVC modes do not default to 1280x720")
if "return {mjpeg, yuyv};" not in fallback:
    raise SystemExit("fallback UVC modes do not default to MJPEG")
PY
ok "MJPEG 1280x720 defaults with real MI8 rates, 30 and 15 FPS"

require_fixed "$uvc_provider" "getFrameAndQueueBufferToGadgetDriver(true)" \
    "the first encoded frame is not queued before STREAMON"
require_fixed "$webcam_buffer" "mProducerBufferFilled.wait_for(l, 5s)" \
    "encoded-frame waits are not bounded"
require_fixed "$uvc_provider" "parent->watchControlEvents()" \
    "a failed stream cannot return to control-event polling"
require_fixed "$uvc_provider" "errno == EAGAIN || errno == EINTR" \
    "transient DQBUF errors are not separated from fatal failures"
require_fixed "$uvc_provider" "inotify_init1(IN_NONBLOCK | IN_CLOEXEC)" \
    "V4L2 node monitoring can block native service shutdown"
require_fixed "$uvc_provider" "Release the delayed SET_INTERFACE status" \
    "failed native stream initialization can leave the USB host request pending"
require_fixed "$webcam_camera" "CAMERA_OPERATION_TIMEOUT_MS = 5000" \
    "camera operations are not bounded"
require_fixed "$webcam_camera" "mCameraOperationGeneration" \
    "stale camera callbacks are not rejected"
require_fixed "$webcam_camera" "mCaptureSessionGeneration" \
    "stale capture-session callbacks are not rejected"
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

require_fixed "$webcam_service" "Keep returnImage() available while" \
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
    service_destroy.index("mServiceRunning = false"),
    service_destroy.index("webcamController.onDestroy()"),
)
if tuple(sorted(service_order)) != service_order:
    raise SystemExit("Java service teardown is not ordered native-drain then camera cleanup")

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
    "camera stream rotation is incorrect"
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
if ui.count("rotation - sensorOrientation + 360") != 2:
    raise SystemExit("front and rear UI controls do not follow the physical phone orientation")

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
grep -Eq '^#define[[:space:]]+UVC_NUM_REQUESTS[[:space:]]+320$' "$kernel_uvc_header" ||
    fail "UVC request pool is not the audited 320-request pool"
grep -Eq '^#define[[:space:]]+UVC_ISOC_REQUESTS_IN_FLIGHT[[:space:]]+64$' \
    "$kernel_uvc_header" ||
    fail "UVC isochronous in-flight depth is not bounded to 64 requests"
require_fixed "$kernel_uvc_function" "uvc_function_setup_continue" \
    "SET_INTERFACE completion is not synchronized with userspace"
require_fixed "$kernel_uvc_header" "UVC_DELAYED_STATUS_STREAM_ON" \
    "SET_INTERFACE delayed-status state is not tracked"
require_fixed "$kernel_uvc_v4l2" "atomic_xchg(&uvc->delayed_status" \
    "failed stream starts cannot release delayed SET_INTERFACE status"
require_fixed "$kernel_uvc_video" "uvc_video_queue_initial_requests" \
    "isochronous endpoint priming is missing"
require_fixed "$kernel_uvc_video" "count < UVC_ISOC_REQUESTS_IN_FLIGHT" \
    "the UVC endpoint does not use the bounded in-flight request depth"
require_fixed "$kernel_uvc_video" "case -EXDEV:" \
    "missed isochronous transfers are not recovered"
require_fixed "$kernel_uvc_video" "empty ready list is normal back-pressure" \
    "empty encoded queues are not treated as recoverable back-pressure"
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
ok "upstream-style isochronous request flow, recoverable back-pressure and shutdown drain"

printf '\nPASS: CaCamOS source tree satisfies the static pre-build gates.\n'
printf 'Runtime UVC and OBS validation is still required after installation.\n'
