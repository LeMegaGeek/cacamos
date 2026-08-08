#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../.." && pwd)"
adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
expected_build_incremental="${EXPECTED_BUILD_INCREMENTAL:-}"
expected_cacamos_version="$(
    tr -d '\r\n' < "$script_dir/../VERSION"
)"
expected_cacamos_version="${EXPECTED_CACAMOS_VERSION:-$expected_cacamos_version}"
[[ "$expected_cacamos_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf 'ERROR: invalid expected CaCamOS version: %s\n' \
        "$expected_cacamos_version" >&2
    exit 2
}
report_dir="${1:-$project_root/dist/cacam-os-qualifications}"
failures=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

pass() {
    printf 'PASS: %s\n' "$*"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'ERROR: missing command: %s\n' "$1" >&2
        exit 127
    }
}

require_cmd "$adb_bin"
require_cmd awk
require_cmd lsusb
require_cmd python3
require_cmd v4l2-ctl

if [[ -z "$adb_serial" ]]; then
    mapfile -t android_serials < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    if [[ "${#android_serials[@]}" -ne 1 ]]; then
        printf 'ERROR: expected exactly one running ADB device, found %s\n' \
            "${#android_serials[@]}" >&2
        exit 1
    fi
    adb_serial="${android_serials[0]}"
fi
adb_cmd=("$adb_bin" -s "$adb_serial")

adb_exec() {
    "${adb_cmd[@]}" "$@"
}

adb_shell() {
    adb_exec shell "$@" 2>/dev/null | tr -d '\r'
}

if [[ "$(adb_exec get-state 2>/dev/null | tr -d '\r')" != "device" ]]; then
    printf 'ERROR: ADB target %s is not a running Android device\n' "$adb_serial" >&2
    exit 1
fi

mkdir -p "$report_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
report="$report_dir/${timestamp}-dipper-runtime.txt"
exec > >(tee "$report") 2>&1

printf 'CaCamOS MI8 runtime qualification\n'
printf 'date=%s\n' "$(date -Is)"
printf 'adb_target=%s\n' "$adb_serial"

device="$(adb_shell getprop ro.product.device)"
model="$(adb_shell getprop ro.product.model)"
brand="$(adb_shell getprop ro.product.brand)"
lineage="$(adb_shell getprop ro.lineage.version)"
cacamos_appliance="$(adb_shell getprop ro.cacamos.appliance)"
cacamos_version="$(adb_shell getprop ro.cacamos.version)"
setupwizard_mode="$(adb_shell getprop ro.setupwizard.mode)"
build_fingerprint="$(adb_shell getprop ro.build.fingerprint)"
build_incremental="$(adb_shell getprop ro.build.version.incremental)"
boot_completed="$(adb_shell getprop sys.boot_completed)"
boot_reason="$(adb_shell getprop ro.boot.bootreason)"
uptime_raw="$(adb_shell cat /proc/uptime)"
uptime="${uptime_raw%% *}"
usb_config="$(adb_shell getprop sys.usb.config)"
persist_usb_config="$(adb_shell getprop persist.sys.usb.config)"
adb_wifi_enabled="$(adb_shell settings get global adb_wifi_enabled)"
adb_enabled="$(adb_shell settings get global adb_enabled)"
adb_tcp_port="$(adb_shell getprop service.adb.tcp.port)"
persist_adb_tcp_port="$(adb_shell getprop persist.adb.tcp.port)"
device_provisioned="$(adb_shell settings get global device_provisioned)"
user_setup_complete="$(adb_shell settings get secure user_setup_complete)"
development_settings_enabled="$(
    adb_shell settings get global development_settings_enabled
)"
# SELinux intentionally hides the UVC and adbd properties from shell. Verify
# their framework policy and the applied HAL state instead.
uvc_default_enabled="$(
    adb_shell cmd overlay lookup android android:bool/config_usbDefaultToUvc
)"
adb_wifi_auto_enabled="$(
    adb_shell cmd overlay lookup android android:bool/config_adbWifiAutoEnable
)"
webcam_package="$(adb_shell pm list packages com.android.DeviceAsWebcam)"
record_audio_permission="$(
    adb_shell dumpsys package check-permission \
        android.permission.RECORD_AUDIO com.android.DeviceAsWebcam 0
)"
system_packages="$(adb_shell pm list packages -s)"
webcam_pid="$(adb_shell pidof com.android.DeviceAsWebcam)"
lockscreen_disabled="$(adb_shell locksettings get-disabled)"
double_tap_to_wake="$(adb_shell settings get secure double_tap_to_wake)"
trust_dump="$(adb_shell dumpsys trust)"
usb_dump="$(adb_shell dumpsys usb)"
power_dump="$(adb_shell dumpsys power)"
activity_dump="$(adb_shell dumpsys activity activities)"
policy_dump="$(adb_shell dumpsys window policy)"
home_activity="$(
    adb_shell cmd package resolve-activity --brief \
        -a android.intent.action.MAIN -c android.intent.category.HOME
)"
crash_dump="$(adb_exec logcat -b crash -d -v brief 2>/dev/null | tr -d '\r')"
kernel_config="$(adb_shell 'zcat /proc/config.gz 2>/dev/null')"

printf '\nAndroid\n'
printf 'model=%s\n' "$model"
printf 'brand=%s\n' "$brand"
printf 'device=%s\n' "$device"
printf 'lineage=%s\n' "$lineage"
printf 'cacamos_appliance=%s\n' "$cacamos_appliance"
printf 'cacamos_version=%s\n' "$cacamos_version"
printf 'setupwizard_mode=%s\n' "$setupwizard_mode"
printf 'fingerprint=%s\n' "$build_fingerprint"
printf 'build_incremental=%s\n' "$build_incremental"
printf 'boot_completed=%s\n' "$boot_completed"
printf 'boot_reason=%s\n' "$boot_reason"
printf 'uptime_seconds=%s\n' "$uptime"
printf 'config_usbDefaultToUvc=%s\n' "$uvc_default_enabled"
printf 'sys.usb.config=%s\n' "$usb_config"
printf 'persist.sys.usb.config=%s\n' "$persist_usb_config"
printf 'adb_wifi_enabled=%s\n' "$adb_wifi_enabled"
printf 'adb_enabled=%s\n' "$adb_enabled"
printf 'service.adb.tcp.port=%s\n' "${adb_tcp_port:-unset}"
printf 'persist.adb.tcp.port=%s\n' "${persist_adb_tcp_port:-unset}"
printf 'config_adbWifiAutoEnable=%s\n' "$adb_wifi_auto_enabled"
printf 'webcam_pid=%s\n' "$webcam_pid"
printf 'lockscreen_disabled=%s\n' "$lockscreen_disabled"
printf 'double_tap_to_wake=%s\n' "$double_tap_to_wake"
printf 'device_provisioned=%s\n' "$device_provisioned"
printf 'user_setup_complete=%s\n' "$user_setup_complete"
printf 'development_settings_enabled=%s\n' "$development_settings_enabled"
printf 'home_activity=%s\n' "$home_activity"

[[ "$device" == "dipper" ]] && pass "the connected device is dipper" ||
    fail "expected dipper, found ${device:-unset}"
[[ "$model" == "CaCamOS MI 8 Webcam" ]] &&
    pass "the dedicated CaCamOS product identity is installed" ||
    fail "unexpected product model: ${model:-unset}"
[[ "$brand" == "CaCamOS" ]] &&
    pass "the Android product brand is CaCamOS" ||
    fail "unexpected product brand: ${brand:-unset}"
[[ "$cacamos_appliance" == "true" &&
    "$cacamos_version" == "$expected_cacamos_version" ]] &&
    pass "the installed system is CaCamOS appliance $expected_cacamos_version" ||
    fail "expected CaCamOS appliance $expected_cacamos_version"
[[ "$setupwizard_mode" == "DISABLED" ]] &&
    pass "the setup wizard is disabled" ||
    fail "setup wizard mode is ${setupwizard_mode:-unset}"
if [[ -n "$expected_build_incremental" ]]; then
    [[ "$build_incremental" == "$expected_build_incremental" ]] &&
        pass "the exact expected build is installed" ||
        fail "build incremental is ${build_incremental:-unset}, expected $expected_build_incremental"
fi
[[ "$boot_completed" == "1" ]] && pass "Android boot completed" ||
    fail "sys.boot_completed is ${boot_completed:-unset}"
[[ "$uvc_default_enabled" == "true" ]] &&
    pass "the build defaults to Android UVC" ||
    fail "config_usbDefaultToUvc is ${uvc_default_enabled:-unset}"
[[ "$webcam_package" == "package:com.android.DeviceAsWebcam" ]] &&
    pass "DeviceAsWebcam is installed" ||
    fail "DeviceAsWebcam package is missing"
consumer_packages=(
    com.android.calendar
    com.android.camera2
    com.android.contacts
    com.android.deskclock
    com.android.dialer
    com.android.gallery3d
    com.android.launcher3
    com.android.managedprovisioning
    com.android.music
    com.android.quicksearchbox
    org.lineageos.aperture
    org.lineageos.eleven
    org.lineageos.etar
    org.lineageos.jelly
    org.lineageos.setupwizard
)
remaining_consumer_packages=()
for package_name in "${consumer_packages[@]}"; do
    if grep -Fxq "package:$package_name" <<<"$system_packages"; then
        remaining_consumer_packages+=("$package_name")
    fi
done
if [[ "${#remaining_consumer_packages[@]}" -eq 0 ]]; then
    pass "consumer applications and the generic launcher are absent"
else
    fail "consumer applications remain: ${remaining_consumer_packages[*]}"
fi
[[ "$webcam_pid" =~ ^[0-9]+$ ]] && pass "DeviceAsWebcam process is alive" ||
    fail "DeviceAsWebcam process is not alive"
[[ "$device_provisioned" == "1" && "$user_setup_complete" == "1" ]] &&
    pass "the appliance is provisioned without a consumer setup flow" ||
    fail "the appliance is not fully provisioned"
[[ "$development_settings_enabled" == "1" ]] &&
    pass "the maintenance settings entry is enabled" ||
    fail "maintenance settings are not enabled"
grep -Fq \
    'com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamPreview' \
    <<<"$home_activity" &&
    pass "the webcam preview is the only HOME activity" ||
    fail "the webcam preview is not the resolved HOME activity"

for option in \
    CONFIG_MEDIA_SUPPORT=y \
    CONFIG_USB_GADGET=y \
    CONFIG_USB_CONFIGFS=y \
    CONFIG_USB_CONFIGFS_F_UAC2=y \
    CONFIG_USB_CONFIGFS_F_UVC=y; do
    grep -Fxq "$option" <<<"$kernel_config" &&
        pass "kernel has $option" ||
        fail "kernel is missing $option"
done

current_functions="$(
    awk -F= '/^[[:space:]]*current_functions=/{print $2; exit}' <<<"$usb_dump"
)"
functions_applied="$(
    awk -F= '/^[[:space:]]*current_functions_applied=/{print $2; exit}' <<<"$usb_dump"
)"
usb_connected="$(
    awk -F= '/^[[:space:]]*connected=/{print $2; exit}' <<<"$usb_dump"
)"
usb_configured="$(
    awk -F= '/^[[:space:]]*configured=/{print $2; exit}' <<<"$usb_dump"
)"
kernel_state="$(
    awk -F= '/^[[:space:]]*kernel_state=/{print $2; exit}' <<<"$usb_dump"
)"

printf '\nUSB gadget\n'
printf 'current_functions=%s\n' "${current_functions:-unset}"
printf 'current_functions_applied=%s\n' "${functions_applied:-unset}"
printf 'connected=%s\n' "${usb_connected:-unset}"
printf 'configured=%s\n' "${usb_configured:-unset}"
printf 'kernel_state=%s\n' "${kernel_state:-unset}"

[[ "$current_functions" == "0x80" ]] &&
    pass "the cable composition is exactly UVC" ||
    fail "expected exact UVC function 0x80, found ${current_functions:-unset}"
[[ "$functions_applied" == "true" ]] && pass "the UVC function is applied" ||
    fail "the current USB function is not applied"
[[ "$usb_connected" == "true" && "$usb_configured" == "true" &&
    "$kernel_state" == "CONFIGURED" ]] &&
    pass "the host configured the USB gadget" ||
    fail "the USB gadget is not fully configured"

if [[ "$adb_serial" == *:* ]]; then
    pass "ADB uses a network endpoint"
else
    fail "ADB target $adb_serial is not a network endpoint"
fi
mapfile -t active_adb_transports < <(
    "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
)
for transport in "${active_adb_transports[@]}"; do
    if [[ "$transport" != *:* ]]; then
        fail "USB ADB transport is exposed on the audio/video-only cable: $transport"
    fi
done
[[ "$adb_wifi_enabled" == "1" ]] && pass "wireless debugging is enabled" ||
    fail "adb_wifi_enabled is ${adb_wifi_enabled:-unset}"
[[ "$adb_enabled" == "1" ]] && pass "ADB maintenance is enabled" ||
    fail "adb_enabled is ${adb_enabled:-unset}"
[[ "$adb_wifi_auto_enabled" == "true" ]] &&
    pass "automatic wireless debugging is configured" ||
    fail "config_adbWifiAutoEnable is ${adb_wifi_auto_enabled:-unset}"
[[ -z "$adb_tcp_port" || "$adb_tcp_port" == "-1" ]] &&
    [[ -z "$persist_adb_tcp_port" || "$persist_adb_tcp_port" == "-1" ]] &&
    pass "legacy unauthenticated ADB-over-TCP is disabled" ||
    fail "legacy ADB TCP port is configured"

grep -Eq \
    'topResumedActivity=.*com\.android\.DeviceAsWebcam/com\.android\.deviceaswebcam\.DeviceAsWebcamPreview' \
    <<<"$activity_dump" &&
    pass "the webcam preview is the resumed activity" ||
    fail "the webcam preview is not the resumed activity"

[[ "$lockscreen_disabled" == "true" ]] &&
    grep -Eq 'deviceLocked=0|deviceLocked=false' <<<"$trust_dump" &&
    pass "the device has no active lock screen" ||
    fail "the device is still locked or has a secure credential"

if grep -Fq 'secure=true' <<<"$policy_dump"; then
    fail "KeyguardService still reports a secure lock"
else
    pass "KeyguardService reports no secure lock"
fi

[[ "$double_tap_to_wake" == "1" ]] &&
    pass "double-tap touch wake is enabled" ||
    fail "double_tap_to_wake is ${double_tap_to_wake:-unset}"
grep -Fq 'mDoubleTapWakeEnabled=true' <<<"$power_dump" &&
    pass "the power HAL has enabled double-tap touch wake" ||
    fail "the power HAL has not enabled double-tap touch wake"
grep -Fq 'mUserActivityTimeoutOverrideFromWindowManager=30000' \
    <<<"$power_dump" &&
    pass "the webcam display timeout is 30 seconds" ||
    fail "the webcam display timeout override is not 30 seconds"

if grep -Fq 'com.android.DeviceAsWebcam' <<<"$crash_dump"; then
    fail "the crash buffer contains a DeviceAsWebcam crash"
else
    pass "the crash buffer contains no DeviceAsWebcam crash"
fi

if [[ ! -x "$script_dir/find-cacamos-webcam.sh" ]]; then
    fail "missing CaCamOS host-device detector"
elif ! host_device="$("$script_dir/find-cacamos-webcam.sh" 2>&1)"; then
    fail "$host_device"
else
    host_info="$(v4l2-ctl --device="$host_device" --all 2>&1)"
    host_formats="$(v4l2-ctl --device="$host_device" --list-formats-ext 2>&1)"

    printf '\nHost UVC\n'
    printf 'device=%s\n' "$host_device"
    printf '%s\n' "$host_formats"

    grep -Eq 'Driver name[[:space:]]*: uvcvideo' <<<"$host_info" &&
        pass "Linux bound the standard uvcvideo driver" ||
        fail "the host node is not bound to uvcvideo"
    grep -Fiq 'CaCamOS Webcam' <<<"$host_info" &&
        pass "the host identifies the dedicated CaCamOS webcam" ||
        fail "the host card name does not expose the CaCamOS identity"

    if python3 - "$host_formats" <<'PY'
import re
import sys

text = sys.argv[1]
rates = {
    round(float(value))
    for value in re.findall(r"\(([0-9]+(?:\.[0-9]+)?) fps\)", text)
}
if rates != {15, 30}:
    raise SystemExit(f"advertised rates are {sorted(rates)}, expected [15, 30]")
if (
    "'MJPG'" not in text
    or "1280x720" not in text
    or "1024x576" not in text
    or "1920x1080" not in text
):
    raise SystemExit("required MJPEG 576p/720p/1080p modes are missing")
if "640x360" in text or "'YUYV'" in text:
    raise SystemExit("obsolete 360p or uncompressed mode is still advertised")
PY
    then
        pass "the host sees only real 15/30 FPS MJPEG modes"
    else
        fail "the host UVC descriptors do not match the audited mode set"
    fi
fi

if [[ "$record_audio_permission" == "0" ]]; then
    pass "DeviceAsWebcam has the fixed microphone permission"
else
    fail "DeviceAsWebcam microphone permission result is ${record_audio_permission:-unset}"
fi

if [[ ! -x "$script_dir/find-cacamos-audio.sh" ]]; then
    fail "missing CaCamOS host-audio detector"
elif ! host_audio="$("$script_dir/find-cacamos-audio.sh" 2>&1)"; then
    fail "$host_audio"
else
    printf '\nHost UAC2\n'
    printf '%s\n' "$host_audio"
    grep -Eq '^microphone=plughw:[0-9]+,[0-9]+$' <<<"$host_audio" &&
        pass "Linux exposes the CaCamOS standard microphone PCM" ||
        fail "the CaCamOS host microphone PCM is missing"
    grep -Eq '^speakers=plughw:[0-9]+,[0-9]+$' <<<"$host_audio" &&
        pass "Linux exposes the CaCamOS standard speakers PCM" ||
        fail "the CaCamOS host speakers PCM is missing"
fi

if usb_descriptors="$(lsusb -v -d 18d1:4eef 2>&1)"; then
    printf '\nComposite USB descriptors\n'
    grep -Eq 'bDeviceClass[[:space:]]+239[[:space:]]' <<<"$usb_descriptors" &&
        grep -Eq 'bDeviceSubClass[[:space:]]+2[[:space:]]' <<<"$usb_descriptors" &&
        grep -Eq 'bDeviceProtocol[[:space:]]+1[[:space:]]' <<<"$usb_descriptors" &&
        pass "the host sees the Windows-compatible composite IAD identity" ||
        fail "the composite device class is not EF/02/01"
    grep -Eq 'bInterfaceClass[[:space:]]+14[[:space:]]' <<<"$usb_descriptors" &&
        pass "the composite device contains a standard video function" ||
        fail "the composite USB descriptors lack the video function"
    grep -Eq 'bInterfaceClass[[:space:]]+1[[:space:]]' <<<"$usb_descriptors" &&
        pass "the composite device contains a standard audio function" ||
        fail "the composite USB descriptors lack the audio function"
else
    fail "lsusb cannot read the CaCamOS composite device 18d1:4eef"
fi

printf '\nreport=%s\n' "$report"
if [[ "$failures" -ne 0 ]]; then
    printf 'FAIL: runtime qualification found %s problem(s).\n' "$failures" >&2
    exit 1
fi

printf 'PASS: CaCamOS %s appliance startup and standard UVC/UAC2 gates passed.\n' \
    "$expected_cacamos_version"
