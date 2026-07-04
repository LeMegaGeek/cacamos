# Current Mi 8 Audit

Audit date: 2026-07-02

MI8 connected and tested with the CaCam OS UVC kernel temporary boot.

Official LineageOS state checked:

```text
device=dipper
latest_build=lineage-22.2-20260627-nightly-dipper-signed.zip
latest_build_sha256=70f75f2f7466374446ec3272da263a22062e68f5426370a8e799d9d6648abd07
boot_sha256=9b2096e2c6ea06f6e7f44ac7f0b5af4370bb645f2eaa5b32ad754e08d9bcb300
branch=lineage-22.2
```

Device tree:

```text
device/xiaomi/dipper
device/xiaomi/sdm845-common
```

USB framework/HAL source state:

```text
vendor/qcom/opensource/usb/hal/UsbGadget.cpp handles GadgetFunction::UVC
vendor/qcom/opensource/usb/hal/UsbGadget.cpp links uvc.0
system/sepolicy/private/hal_usb_gadget.te allows hal_usb_gadget_server to read usb_uvc_enabled_prop
system/sepolicy/private/property_contexts defines ro.usb.uvc.enabled
```

Kernel source state:

```text
kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/mi845_defconfig:
  CONFIG_USB_GADGET=y
  CONFIG_USB_CONFIGFS=y
  CONFIG_USB_VIDEO_CLASS=<missing>
  CONFIG_USB_CONFIGFS_F_UVC=<missing>

kernel/xiaomi/sdm845/arch/arm64/configs/vendor/xiaomi/dipper.config:
  CONFIG_USB_VIDEO_CLASS=<missing>
  CONFIG_USB_CONFIGFS_F_UVC=<missing>
```

Runtime test result:

```text
kernel=4.9.337-perf-gaa8adfe9bf21-dirty
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
ro.usb.uvc.enabled=true
svc usb setFunctions uvc -> HAL accepts UVC
kernel log -> configfs-gadget gadget: uvc_function_bind
DeviceAsWebcam -> opens /dev/video0 (sde_rotator), then fails subscribing to UVC_EVENT_SETUP
host Linux -> MI8 remains 18d1:4e11 ADB, no UVC /dev/video node yet
```

Temporary runtime simulation of `ignored_v4l2_nodes.json`:

```text
internal nodes /dev/video0,1,2,32,33 temporarily blocked
DeviceAsWebcam -> opens /dev/video3
/sys/class/video4linux/video3 -> .../a600000.dwc3/gadget/video4linux/video3
host lsusb -> 18d1:4eee Google Inc. Xiaomi Mi 8
host uvcvideo -> Found UVC 1.50 device Xiaomi Mi 8
host uvcvideo -> Failed to query UVC probe control, device initialization -5
```

That proves the MI8 overlay node filter is correct. The remaining source fix is
service timing: DeviceAsWebcam must be awake and retrying before the USB gadget
is pulled up, otherwise the host probes UVC before Android is listening.

Conclusion:

The MI8 needs a source build patch. A Magisk property-only module is not enough
for stock `dipper` because the current kernel config does not enable the UVC
gadget function. The CaCam OS `dipper` addon adds:

```text
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
DeviceAsWebcam
ro.usb.uvc.enabled=true
ignored_v4l2_nodes.json for MI8 internal video nodes
DeviceAsWebcam pre-wake/retry before UVC host enumeration
```
