#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../.." && pwd)"
adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
expected_build_incremental="${EXPECTED_BUILD_INCREMENTAL:-}"
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
lineage="$(adb_shell getprop ro.lineage.version)"
build_fingerprint="$(adb_shell getprop ro.build.fingerprint)"
build_incremental="$(adb_shell getprop ro.build.version.incremental)"
boot_completed="$(adb_shell getprop sys.boot_completed)"
boot_reason="$(adb_shell getprop ro.boot.bootreason)"
uptime_raw="$(adb_shell cat /proc/uptime)"
uptime="${uptime_raw%% *}"
usb_config="$(adb_shell getprop sys.usb.config)"
persist_usb_config="$(adb_shell getprop persist.sys.usb.config)"
adb_wifi_enabled="$(adb_shell settings get global adb_wifi_enabled)"
# SELinux intentionally hides the UVC and adbd properties from shell. Verify
# their framework policy and the applied HAL state instead.
uvc_default_enabled="$(
    adb_shell cmd overlay lookup android android:bool/config_usbDefaultToUvc
)"
adb_wifi_auto_enabled="$(
    adb_shell cmd overlay lookup android android:bool/config_adbWifiAutoEnable
)"
webcam_package="$(adb_shell pm list packages com.android.DeviceAsWebcam)"
webcam_pid="$(adb_shell pidof com.android.DeviceAsWebcam)"
lockscreen_disabled="$(adb_shell locksettings get-disabled)"
trust_dump="$(adb_shell dumpsys trust)"
usb_dump="$(adb_shell dumpsys usb)"
activity_dump="$(adb_shell dumpsys activity activities)"
policy_dump="$(adb_shell dumpsys window policy)"
crash_dump="$(adb_exec logcat -b crash -d -v brief 2>/dev/null | tr -d '\r')"
kernel_config="$(adb_shell 'zcat /proc/config.gz 2>/dev/null')"

printf '\nAndroid\n'
printf 'model=%s\n' "$model"
printf 'device=%s\n' "$device"
printf 'lineage=%s\n' "$lineage"
printf 'fingerprint=%s\n' "$build_fingerprint"
printf 'build_incremental=%s\n' "$build_incremental"
printf 'boot_completed=%s\n' "$boot_completed"
printf 'boot_reason=%s\n' "$boot_reason"
printf 'uptime_seconds=%s\n' "$uptime"
printf 'config_usbDefaultToUvc=%s\n' "$uvc_default_enabled"
printf 'sys.usb.config=%s\n' "$usb_config"
printf 'persist.sys.usb.config=%s\n' "$persist_usb_config"
printf 'adb_wifi_enabled=%s\n' "$adb_wifi_enabled"
printf 'config_adbWifiAutoEnable=%s\n' "$adb_wifi_auto_enabled"
printf 'webcam_pid=%s\n' "$webcam_pid"
printf 'lockscreen_disabled=%s\n' "$lockscreen_disabled"

[[ "$device" == "dipper" ]] && pass "the connected device is dipper" ||
    fail "expected dipper, found ${device:-unset}"
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
[[ "$webcam_pid" =~ ^[0-9]+$ ]] && pass "DeviceAsWebcam process is alive" ||
    fail "DeviceAsWebcam process is not alive"

for option in \
    CONFIG_MEDIA_SUPPORT=y \
    CONFIG_USB_GADGET=y \
    CONFIG_USB_CONFIGFS=y \
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
[[ "$adb_wifi_enabled" == "1" ]] && pass "wireless debugging is enabled" ||
    fail "adb_wifi_enabled is ${adb_wifi_enabled:-unset}"
[[ "$adb_wifi_auto_enabled" == "true" ]] &&
    pass "automatic wireless debugging is configured" ||
    fail "config_adbWifiAutoEnable is ${adb_wifi_auto_enabled:-unset}"

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

if grep -Fq 'com.android.DeviceAsWebcam' <<<"$crash_dump"; then
    fail "the crash buffer contains a DeviceAsWebcam crash"
else
    pass "the crash buffer contains no DeviceAsWebcam crash"
fi

shopt -s nullglob
host_candidates=(/dev/v4l/by-id/usb-Xiaomi_Xiaomi_Mi_8_*video-index0)
shopt -u nullglob
if [[ "${#host_candidates[@]}" -ne 1 ]]; then
    fail "expected one Xiaomi Mi 8 host capture node, found ${#host_candidates[@]}"
else
    host_device="${host_candidates[0]}"
    host_info="$(v4l2-ctl --device="$host_device" --all 2>&1)"
    host_formats="$(v4l2-ctl --device="$host_device" --list-formats-ext 2>&1)"

    printf '\nHost UVC\n'
    printf 'device=%s\n' "$host_device"
    printf '%s\n' "$host_formats"

    grep -Eq 'Driver name[[:space:]]*: uvcvideo' <<<"$host_info" &&
        pass "Linux bound the standard uvcvideo driver" ||
        fail "the host node is not bound to uvcvideo"
    grep -Fq 'Xiaomi Mi 8: UVC Camera' <<<"$host_info" &&
        pass "the host identifies the MI8 UVC camera" ||
        fail "the host card name is not the MI8 UVC camera"

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
if "'MJPG'" not in text or "1280x720" not in text or "1920x1080" not in text:
    raise SystemExit("required MJPEG 720p/1080p modes are missing")
PY
    then
        pass "the host sees only real 15/30 FPS MJPEG modes"
    else
        fail "the host UVC descriptors do not match the audited mode set"
    fi
fi

printf '\nreport=%s\n' "$report"
if [[ "$failures" -ne 0 ]]; then
    printf 'FAIL: runtime qualification found %s problem(s).\n' "$failures" >&2
    exit 1
fi

printf 'PASS: automatic startup, lock state, wireless ADB and host UVC gates passed.\n'
