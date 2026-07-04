#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$1" >&2
        exit 127
    fi
}

adb_shell() {
    "$adb_bin" shell "$@" 2>/dev/null || true
}

detect_su() {
    if "$adb_bin" shell su -c id >/dev/null 2>&1; then
        printf 'su'
        return 0
    fi
    if "$adb_bin" shell /debug_ramdisk/su -c id >/dev/null 2>&1; then
        printf '/debug_ramdisk/su'
        return 0
    fi
    return 1
}

adb_root_shell() {
    local su_bin="$1"
    shift
    "$adb_bin" shell "$su_bin" -c "$*" 2>/dev/null || true
}

require_cmd "$adb_bin"

printf 'Waiting for Android device...\n'
"$adb_bin" wait-for-device

device="$(adb_shell getprop ro.product.device | tr -d '\r')"
model="$(adb_shell getprop ro.product.model | tr -d '\r')"
uvc_enabled="$(adb_shell getprop ro.usb.uvc.enabled | tr -d '\r')"
usb_config="$(adb_shell getprop sys.usb.config | tr -d '\r')"
usb_state="$(adb_shell getprop sys.usb.state | tr -d '\r')"
webcam_package="$(adb_shell pm list packages com.android.DeviceAsWebcam | tr -d '\r')"
su_bin="$(detect_su || true)"

if [[ -n "$su_bin" && "$uvc_enabled" != "true" ]]; then
    uvc_enabled_root="$(adb_root_shell "$su_bin" getprop ro.usb.uvc.enabled | tr -d '\r')"
    if [[ -n "$uvc_enabled_root" ]]; then
        uvc_enabled="$uvc_enabled_root"
    fi
else
    uvc_enabled_root=""
fi

printf '\nAndroid device\n'
printf '  model: %s\n' "${model:-unknown}"
printf '  ro.product.device: %s\n' "${device:-unknown}"
printf '  ro.usb.uvc.enabled: %s\n' "${uvc_enabled:-unset}"
if [[ -n "$su_bin" ]]; then
    printf '  root helper: %s\n' "$su_bin"
fi
printf '  sys.usb.config: %s\n' "${usb_config:-unset}"
printf '  sys.usb.state: %s\n' "${usb_state:-unset}"
printf '  DeviceAsWebcam package: %s\n' "${webcam_package:-missing}"

printf '\nUSB service\n'
adb_shell cmd usb get-current-functions | sed 's/^/  /'

printf '\nAndroid video nodes\n'
adb_shell ls -l /dev/video* | sed 's/^/  /'

if [[ "$device" != "cmi" ]]; then
    printf '\nWARNING: expected ro.product.device=cmi, got %s\n' "${device:-unset}" >&2
fi

if [[ "$uvc_enabled" != "true" ]]; then
    printf '\nFAIL: ro.usb.uvc.enabled is not true.\n' >&2
    exit 1
fi

printf '\nHost webcam devices\n'
if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --list-devices || true
else
    printf '  v4l2-ctl not installed; on Linux install v4l-utils to list host cameras.\n'
fi

printf '\nOK: UVC support is advertised by the Android build.\n'
