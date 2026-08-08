#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
expected_version="${EXPECTED_CACAMOS_VERSION:-}"
idle_seconds="${IDLE_SECONDS:-40}"
wake_timeout_seconds="${WAKE_TIMEOUT_SECONDS:-30}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'PASS: %s\n' "$*"
}

command -v "$adb_bin" >/dev/null 2>&1 || fail "adb is unavailable"
[[ "$idle_seconds" =~ ^[1-9][0-9]*$ ]] || fail "IDLE_SECONDS must be positive"
[[ "$wake_timeout_seconds" =~ ^[1-9][0-9]*$ ]] ||
    fail "WAKE_TIMEOUT_SECONDS must be positive"

if [[ -z "$adb_serial" ]]; then
    mapfile -t devices < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    [[ "${#devices[@]}" -eq 1 ]] ||
        fail "set ADB_SERIAL when more than one Android device is connected"
    adb_serial="${devices[0]}"
fi

adb_cmd=("$adb_bin" -s "$adb_serial")
adb_shell() {
    "${adb_cmd[@]}" shell "$@" 2>/dev/null | tr -d '\r'
}

[[ "$("${adb_cmd[@]}" get-state 2>/dev/null | tr -d '\r')" == "device" ]] ||
    fail "$adb_serial is not available"

device="$(adb_shell getprop ro.product.device)"
version="$(adb_shell getprop ro.cacamos.version)"
[[ "$device" == "dipper" || "$device" == "cmi" ]] ||
    fail "unsupported device: ${device:-unset}"
[[ "$version" =~ ^1\.[0-9]+\.[0-9]+$ ]] ||
    fail "CaCamOS 1.x is not installed"
if [[ -n "$expected_version" && "$version" != "$expected_version" ]]; then
    fail "expected CaCamOS $expected_version, found $version"
fi

printf 'CaCamOS idle energy check\n'
printf 'device=%s\nversion=%s\nadb_target=%s\n' "$device" "$version" "$adb_serial"
printf 'Close every host application using the CaCamOS microphone or speakers.\n'

adb_shell input keyevent KEYCODE_WAKEUP >/dev/null
adb_shell am start -W -n \
    com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamPreview \
    >/dev/null
sleep 2

double_tap_to_wake="$(adb_shell settings get secure double_tap_to_wake)"
initial_power="$(adb_shell dumpsys power)"
[[ "$double_tap_to_wake" == "1" ]] ||
    fail "double_tap_to_wake=${double_tap_to_wake:-unset}"
grep -Fq 'mUserActivityTimeoutOverrideFromWindowManager=30000' \
    <<<"$initial_power" || fail "the active webcam window has no 30-second timeout"
grep -Fq 'mDoubleTapWakeEnabled=true' <<<"$initial_power" ||
    fail "the power HAL did not enable double-tap touch wake"
pass "30-second timeout and hardware double-tap touch wake are configured"

printf 'Waiting %s seconds without injecting user activity...\n' "$idle_seconds"
sleep "$idle_seconds"

power_dump="$(adb_shell dumpsys power)"
display_dump="$(adb_shell dumpsys display)"
webcam_pid="$(adb_shell pidof com.android.DeviceAsWebcam)"
camera_dump="$(adb_shell dumpsys media.camera)"

if grep -Fq 'mScreenState=OFF' <<<"$display_dump" ||
    grep -Fq 'mWakefulness=Asleep' <<<"$power_dump"; then
    pass "the display switched off after inactivity"
else
    fail "the display is still on after ${idle_seconds} seconds"
fi

if grep -Eq "PARTIAL_WAKE_LOCK[[:space:]]+'AudioIn'" <<<"$power_dump"; then
    fail "AudioIn is still held; close the host microphone or inspect the audio bridge"
else
    pass "no AudioIn wake lock is held while host audio is idle"
fi

[[ "$webcam_pid" =~ ^[0-9]+$ ]] || fail "DeviceAsWebcam stopped with the display"
pass "the webcam service remains available with the display off"

active_camera_section="$(
    sed -n '/Active Camera Clients:/,/Allowed user IDs:/p' <<<"$camera_dump"
)"
grep -Fq 'Active Camera Clients:' <<<"$active_camera_section" ||
    fail "camera service did not report its active-client state"
if grep -Fq '(Camera ID:' <<<"$active_camera_section"; then
    fail "the camera remains active with the display and host UVC stream idle"
fi
pass "the camera is idle while neither preview nor host UVC is active"

printf '\nDouble-tap the dark phone screen within %s seconds.\n' \
    "$wake_timeout_seconds"
wake_deadline=$((SECONDS + wake_timeout_seconds))
screen_awake=0
while (( SECONDS < wake_deadline )); do
    display_dump="$(adb_shell dumpsys display)"
    power_dump="$(adb_shell dumpsys power)"
    if grep -Fq 'mScreenState=ON' <<<"$display_dump" ||
        grep -Fq 'mWakefulness=Awake' <<<"$power_dump"; then
        screen_awake=1
        break
    fi
    sleep 1
done
(( screen_awake == 1 )) || fail "the display did not wake from the touch gesture"

sleep 1
activity_dump="$(adb_shell dumpsys activity activities)"
grep -Fq \
    'com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamPreview' \
    <<<"$activity_dump" || fail "the webcam interface did not return after touch wake"
pass "double-tap touch wake restores the CaCamOS webcam interface"
