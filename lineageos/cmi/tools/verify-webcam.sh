#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
release_version="$(tr -d '\r\n' < "$script_dir/../VERSION")"
expected_version="${EXPECTED_CACAMOS_VERSION:-$release_version}"
failures=0

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }

command -v "$adb_bin" >/dev/null 2>&1 || {
    printf 'ERROR: missing adb\n' >&2
    exit 127
}

if [[ -z "$adb_serial" ]]; then
    mapfile -t devices < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    [[ "${#devices[@]}" -eq 1 ]] || {
        printf 'ERROR: expected exactly one running ADB device\n' >&2
        exit 1
    }
    adb_serial="${devices[0]}"
fi

adb_shell() {
    "$adb_bin" -s "$adb_serial" shell "$@" 2>/dev/null | tr -d '\r'
}

device="$(adb_shell getprop ro.product.device)"
model="$(adb_shell getprop ro.product.model)"
brand="$(adb_shell getprop ro.product.brand)"
version="$(adb_shell getprop ro.cacamos.version)"
appliance="$(adb_shell getprop ro.cacamos.appliance)"
boot_completed="$(adb_shell getprop sys.boot_completed)"
uvc_default="$(adb_shell cmd overlay lookup android android:bool/config_usbDefaultToUvc)"
wifi_adb_default="$(adb_shell cmd overlay lookup android android:bool/config_adbWifiAutoEnable)"
webcam_package="$(adb_shell pm list packages com.android.DeviceAsWebcam)"
webcam_pid="$(adb_shell pidof com.android.DeviceAsWebcam)"
lockscreen_disabled="$(adb_shell locksettings get-disabled)"
home_activity="$(adb_shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.HOME)"
usb_dump="$(adb_shell dumpsys usb)"
kernel_config="$(adb_shell 'zcat /proc/config.gz 2>/dev/null')"
system_packages="$(adb_shell pm list packages -s)"
third_party_packages="$(adb_shell pm list packages -3 | sed '/^[[:space:]]*$/d')"
double_tap_to_wake="$(adb_shell settings get secure double_tap_to_wake)"
power_dump="$(adb_shell dumpsys power)"

printf 'CaCamOS MI10 Pro runtime check\n'
printf 'adb_target=%s\n' "$adb_serial"
printf 'model=%s\nbrand=%s\ndevice=%s\nversion=%s\n' \
    "$model" "$brand" "$device" "$version"

[[ "$device" == "cmi" ]] && pass "connected device is cmi" ||
    fail "expected cmi, found ${device:-unset}"
[[ "$model" == "CaCamOS Mi 10 Pro Webcam" && "$brand" == "CaCamOS" ]] &&
    pass "dedicated CaCamOS product identity" ||
    fail "unexpected product identity: ${brand:-unset} / ${model:-unset}"
[[ "$version" == "$expected_version" && "$appliance" == "true" ]] &&
    pass "CaCamOS appliance $expected_version is installed" ||
    fail "expected CaCamOS appliance $expected_version"
[[ "$boot_completed" == "1" ]] && pass "Android boot completed" ||
    fail "Android boot is incomplete"
[[ "$uvc_default" == "true" ]] && pass "USB defaults to UVC" ||
    fail "config_usbDefaultToUvc=${uvc_default:-unset}"
[[ "$wifi_adb_default" == "true" ]] && pass "wireless ADB persists" ||
    fail "config_adbWifiAutoEnable=${wifi_adb_default:-unset}"
[[ "$webcam_package" == "package:com.android.DeviceAsWebcam" ]] &&
    pass "DeviceAsWebcam is installed" || fail "DeviceAsWebcam is missing"
[[ "$webcam_pid" =~ ^[0-9]+$ ]] && pass "DeviceAsWebcam process is alive" ||
    fail "DeviceAsWebcam process is not alive"
[[ "$lockscreen_disabled" == "true" ]] && pass "lock screen is disabled" ||
    fail "lock screen remains enabled"
[[ "$double_tap_to_wake" == "1" ]] && pass "touch wake is enabled" ||
    fail "double_tap_to_wake=${double_tap_to_wake:-unset}"
grep -Fq 'mDoubleTapWakeEnabled=true' <<<"$power_dump" &&
    pass "the power HAL has enabled double-tap touch wake" ||
    fail "the power HAL has not enabled double-tap touch wake"
if grep -Fq 'mUserActivityTimeoutOverrideFromWindowManager=30000' \
    <<<"$power_dump"; then
    pass "webcam screen timeout is 30 seconds"
elif grep -Eq 'mWakefulness=(Asleep|Dozing)' <<<"$power_dump"; then
    pass "webcam display is already asleep after its timeout"
else
    fail "webcam screen timeout override is not 30 seconds"
fi
grep -Fq 'com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamPreview' \
    <<<"$home_activity" && pass "webcam preview is the HOME activity" ||
    fail "webcam preview is not the HOME activity"

for package_name in \
    com.android.gallery3d com.android.launcher3 com.android.music \
    org.lineageos.aperture org.lineageos.eleven org.lineageos.jelly \
    org.lineageos.setupwizard; do
    if grep -Fxq "package:$package_name" <<<"$system_packages"; then
        fail "consumer package remains: $package_name"
    fi
done

if [[ -z "$third_party_packages" ]]; then
    pass "data partition contains no third-party applications"
else
    fail "third-party applications remain in the data partition"
    sed 's/^/  /' <<<"$third_party_packages" >&2
fi

for option in CONFIG_USB_CONFIGFS_F_UVC=y CONFIG_USB_CONFIGFS_F_UAC2=y; do
    grep -Fxq "$option" <<<"$kernel_config" && pass "kernel has $option" ||
        fail "kernel is missing $option"
done

current_functions="$(
    awk -F= '/^[[:space:]]*current_functions=/{print $2; exit}' <<<"$usb_dump"
)"
functions_applied="$(
    awk -F= '/^[[:space:]]*current_functions_applied=/{print $2; exit}' <<<"$usb_dump"
)"
printf 'current_functions=%s\n' "${current_functions:-unset}"
[[ "$current_functions" == "0x80" ]] && pass "UVC owns the cable" ||
    fail "expected UVC function 0x80, found ${current_functions:-unset}"
[[ "$functions_applied" == "true" ]] && pass "USB function is applied" ||
    fail "USB function is not applied"

if [[ "$adb_serial" == *:* ]]; then
    pass "maintenance ADB uses a network endpoint"
else
    fail "maintenance ADB is not using Wi-Fi"
fi

if command -v v4l2-ctl >/dev/null 2>&1; then
    printf '\nHost UVC devices\n'
    v4l2-ctl --list-devices || fail "host UVC enumeration failed"
fi
if command -v arecord >/dev/null 2>&1; then
    printf '\nHost capture devices\n'
    arecord -l || fail "host microphone enumeration failed"
fi
if command -v aplay >/dev/null 2>&1; then
    printf '\nHost playback devices\n'
    aplay -l || fail "host speaker enumeration failed"
fi

if (( failures > 0 )); then
    printf '\nFAILED: %d runtime checks failed.\n' "$failures" >&2
    exit 1
fi

printf '\nPASS: CaCamOS %s runtime invariants are present on cmi.\n' "$expected_version"
