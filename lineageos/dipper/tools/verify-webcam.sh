#!/usr/bin/env bash
set -euo pipefail

adb_base="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"

if [[ -n "$adb_serial" ]]; then
    adb_cmd=("$adb_base" -s "$adb_serial")
else
    adb_cmd=("$adb_base")
fi

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$1" >&2
        exit 127
    fi
}

adb_exec() {
    "${adb_cmd[@]}" "$@"
}

adb_shell() {
    adb_exec shell "$@" 2>/dev/null || true
}

kernel_flag() {
    local flag="$1"
    adb_shell "zcat /proc/config.gz 2>/dev/null | grep -E '^${flag}=|^# ${flag} is not set' || true" | tr -d '\r'
}

require_cmd "${adb_cmd[0]}"

printf 'Waiting for Android device...\n'
adb_exec wait-for-device

device="$(adb_shell getprop ro.product.device | tr -d '\r')"
model="$(adb_shell getprop ro.product.model | tr -d '\r')"
lineage="$(adb_shell getprop ro.lineage.version | tr -d '\r')"
uvc_enabled="$(adb_shell getprop ro.usb.uvc.enabled | tr -d '\r')"
usb_config="$(adb_shell getprop sys.usb.config | tr -d '\r')"
usb_state="$(adb_shell getprop sys.usb.state | tr -d '\r')"
webcam_package="$(adb_shell pm list packages com.android.DeviceAsWebcam | tr -d '\r')"

usb_gadget="$(kernel_flag CONFIG_USB_GADGET)"
usb_configfs="$(kernel_flag CONFIG_USB_CONFIGFS)"
usb_video_class="$(kernel_flag CONFIG_USB_VIDEO_CLASS)"
usb_configfs_uvc="$(kernel_flag CONFIG_USB_CONFIGFS_F_UVC)"

printf '\nAndroid device\n'
printf '  model: %s\n' "${model:-unknown}"
printf '  ro.product.device: %s\n' "${device:-unknown}"
printf '  ro.lineage.version: %s\n' "${lineage:-unknown}"
printf '  ro.usb.uvc.enabled: %s\n' "${uvc_enabled:-unset}"
printf '  sys.usb.config: %s\n' "${usb_config:-unset}"
printf '  sys.usb.state: %s\n' "${usb_state:-unset}"
printf '  DeviceAsWebcam package: %s\n' "${webcam_package:-missing}"

printf '\nKernel UVC config\n'
printf '  %s\n' "${usb_gadget:-CONFIG_USB_GADGET=<missing>}"
printf '  %s\n' "${usb_configfs:-CONFIG_USB_CONFIGFS=<missing>}"
printf '  %s\n' "${usb_video_class:-CONFIG_USB_VIDEO_CLASS=<missing>}"
printf '  %s\n' "${usb_configfs_uvc:-CONFIG_USB_CONFIGFS_F_UVC=<missing>}"

printf '\nUSB service\n'
adb_shell cmd usb get-current-functions | sed 's/^/  /'

printf '\nAndroid video nodes\n'
adb_shell ls -l /dev/video* | sed 's/^/  /'

if [[ "$device" != "dipper" ]]; then
    printf '\nWARNING: expected ro.product.device=dipper, got %s\n' "${device:-unset}" >&2
fi

failures=0
if [[ "$uvc_enabled" != "true" ]]; then
    printf '\nFAIL: ro.usb.uvc.enabled is not true.\n' >&2
    failures=1
fi
if [[ "$usb_video_class" != "CONFIG_USB_VIDEO_CLASS=y" ]]; then
    printf 'FAIL: CONFIG_USB_VIDEO_CLASS is not enabled.\n' >&2
    failures=1
fi
if [[ "$usb_configfs_uvc" != "CONFIG_USB_CONFIGFS_F_UVC=y" ]]; then
    printf 'FAIL: CONFIG_USB_CONFIGFS_F_UVC is not enabled.\n' >&2
    failures=1
fi

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi

printf '\nHost webcam devices\n'
if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --list-devices || true
else
    printf '  v4l2-ctl not installed; on Linux install v4l-utils to list host cameras.\n'
fi

printf '\nOK: UVC support is advertised by the Android build and enabled in the kernel.\n'
