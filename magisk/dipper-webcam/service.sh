#!/system/bin/sh

MODDIR=${0%/*}
LOGFILE="$MODDIR/cacam-os-webcam.log"

device="$(getprop ro.product.device)"
uvc_enabled="$(getprop ro.usb.uvc.enabled)"
webcam_package="$(pm list packages com.android.DeviceAsWebcam 2>/dev/null)"
kernel_uvc="$(zcat /proc/config.gz 2>/dev/null | grep -E '^CONFIG_USB_CONFIGFS_F_UVC=|^# CONFIG_USB_CONFIGFS_F_UVC is not set' || true)"

{
    echo "$(date '+%Y-%m-%d %H:%M:%S') service check"
    echo "device=$device"
    echo "ro.usb.uvc.enabled=$uvc_enabled"
    echo "DeviceAsWebcam=${webcam_package:-missing}"
    echo "kernel=${kernel_uvc:-missing}"
} >> "$LOGFILE"
