#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"
out_dir="${1:-dist/cacam-os-audits}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$1" >&2
        exit 127
    fi
}

adb_shell() {
    "$adb_bin" shell "$@" 2>/dev/null || true
}

section() {
    printf '\n## %s\n\n' "$1"
}

require_cmd "$adb_bin"

printf 'Waiting for Android device...\n'
"$adb_bin" wait-for-device

device="$(adb_shell getprop ro.product.device | tr -d '\r')"
model="$(adb_shell getprop ro.product.model | tr -d '\r')"
serial="$("$adb_bin" get-serialno | tr -d '\r')"
timestamp="$(date +%Y%m%d-%H%M%S)"
safe_device="${device:-unknown}"

mkdir -p "$out_dir"
report="$out_dir/${timestamp}-${safe_device}-${serial}.txt"

{
    printf '# CaCam OS Connected Device Audit\n'
    printf 'date=%s\n' "$(date -Is)"
    printf 'serial=%s\n' "${serial:-unknown}"
    printf 'device=%s\n' "${device:-unknown}"
    printf 'model=%s\n' "${model:-unknown}"

    section "ADB"
    "$adb_bin" devices -l

    section "Android Properties"
    adb_shell 'getprop ro.product.device'
    adb_shell 'getprop ro.product.model'
    adb_shell 'getprop ro.lineage.version'
    adb_shell 'getprop ro.build.version.release'
    adb_shell 'getprop ro.boot.verifiedbootstate'
    adb_shell 'getprop ro.boot.flash.locked'
    adb_shell 'getprop ro.usb.uvc.enabled'
    adb_shell 'getprop sys.usb.config'
    adb_shell 'getprop sys.usb.state'
    adb_shell 'getprop sys.usb.configfs'
    adb_shell 'getenforce'

    section "DeviceAsWebcam"
    adb_shell 'pm list packages com.android.DeviceAsWebcam'
    adb_shell 'cmd package resolve-activity --brief com.android.DeviceAsWebcam 2>/dev/null'

    section "Kernel UVC Config"
    adb_shell "zcat /proc/config.gz 2>/dev/null | grep -E '^(CONFIG_MEDIA_SUPPORT|CONFIG_MEDIA_USB_SUPPORT|CONFIG_USB_GADGET|CONFIG_USB_CONFIGFS|CONFIG_USB_VIDEO_CLASS|CONFIG_USB_CONFIGFS_F_UVC)=|^# (CONFIG_USB_VIDEO_CLASS|CONFIG_USB_CONFIGFS_F_UVC) is not set' || true"

    section "USB Services"
    adb_shell 'ps -AZ | grep -Ei "usb|gadget|webcam"'
    adb_shell 'dumpsys usb | head -140'

    section "ConfigFS"
    adb_shell 'ls -ld /config /config/usb_gadget /config/usb_gadget/g1 /config/usb_gadget/g1/functions 2>&1'
    adb_shell 'ls -l /config/usb_gadget/g1/functions 2>&1 | head -80'

    section "Android Video Nodes"
    adb_shell 'ls -l /dev/video* 2>&1'

    section "Recommended Verify Script"
    case "$device" in
        cmi)
            printf './cacam-os/lineageos/cmi/tools/verify-webcam.sh\n'
            ;;
        dipper)
            printf './cacam-os/lineageos/dipper/tools/verify-webcam.sh\n'
            ;;
        *)
            printf 'No CaCam OS verify script is registered for device=%s\n' "${device:-unknown}"
            ;;
    esac

    section "Host USB"
    if command -v lsusb >/dev/null 2>&1; then
        lsusb
    else
        printf 'lsusb not installed\n'
    fi

    section "Host Video Devices"
    if command -v v4l2-ctl >/dev/null 2>&1; then
        v4l2-ctl --list-devices || true
    else
        printf 'v4l2-ctl not installed; install v4l-utils on Linux.\n'
    fi
} | tee "$report"

printf '\nAudit written to %s\n' "$report"
