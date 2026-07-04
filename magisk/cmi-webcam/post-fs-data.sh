#!/system/bin/sh

MODDIR=${0%/*}
LOGFILE="$MODDIR/cacam-os-webcam.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

device="$(getprop ro.product.device)"
model="$(getprop ro.product.model)"

if [ "$device" != "cmi" ]; then
    log_msg "skip: expected cmi, got device=$device model=$model"
    exit 0
fi

if ! command -v resetprop >/dev/null 2>&1; then
    log_msg "fail: resetprop not found"
    exit 1
fi

resetprop -n ro.usb.uvc.enabled true
log_msg "enabled ro.usb.uvc.enabled=true for device=$device model=$model"
