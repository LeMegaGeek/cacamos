# MI8 Magisk Test Status

Date: 2026-07-02

## Current Phone

```text
ro.product.device=dipper
ro.product.model=MI 8
ro.lineage.version=22.2-20260627-NIGHTLY-dipper
```

## Current Host Connection

Latest host check:

```text
adb devices -l:
2f052c5c device usb:1-2.3.3 product:lineage_dipper model:MI_8 device:dipper
```

ADB is authorized.

## Kernel Result

The CaCam OS kernel-only build succeeded and a temporary `fastboot boot` works.
The running temporary kernel reported:

```text
CONFIG_MEDIA_USB_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

## Remaining Gap

The Magisk-patched CaCam OS UVC boot image was produced on the MI8 and boots
temporarily. Magisk root works through:

```text
/debug_ramdisk/su -c id
uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

The Magisk daemon starts, but its environment is incomplete on this temporary
boot, so modules under `/data/adb/modules` do not auto-run:

```text
Magisk environment incomplete, abort
```

Manual execution of the module script works and sets:

```text
ro.usb.uvc.enabled=true
```

With that property set, `svc usb setFunctions uvc` reaches the QTI USB gadget
HAL and the kernel:

```text
UsbDeviceManager: Setting USB config to uvc
android.hardware.usb.gadget-service.qti: setCurrentUsbFunctions uvc
configfs-gadget gadget: uvc_function_bind
```

The current blocker is now DeviceAsWebcam node selection, not the kernel option
or HAL permission. DeviceAsWebcam opens `/dev/video0`, which is the Qualcomm
`sde_rotator` node, then fails when subscribing to `UVC_EVENT_SETUP`:

```text
DeviceAsWebcam: isVideoOutputDevice device /dev/video0 supports VIDEO_OUTPUT
DeviceAsWebcam: openV4L2DeviceAndSubscribe Couldn't subscribe to V4L2 event 134217732 error Invalid argument
DeviceAsWebcam: UVCDevice: Unable to open and subscribe to V4l2 node /dev/video0 ?
```

After temporarily blocking the internal video nodes, DeviceAsWebcam selects the
real UVC gadget node:

```text
/sys/class/video4linux/video3 -> .../a600000.dwc3/gadget/video4linux/video3
DeviceAsWebcam: isVideoOutputDevice device /dev/video3 supports VIDEO_OUTPUT
DeviceAsWebcam: Started new UVCListenerThread
```

Host Linux then detects the MI8 UVC device, but `uvcvideo` probes too early on
this old path and fails before the Android service is listening:

```text
18d1:4eee Google Inc. Xiaomi Mi 8
Found UVC 1.50 device Xiaomi Mi 8 (18d1:4eee)
Failed to query (129) UVC probe control : 0 (exp. 48)
Failed to initialize the device (-5)
```

The current source addon `0.1.9` adds `ignored_v4l2_nodes.json` for the MI8
internal video nodes, pre-wakes DeviceAsWebcam before UVC pull-up, retries
service setup while the gadget `/dev/videoX` node appears, and ships the
resource-limited MI8 build wrapper with CPU reservation plus a memory watchdog.

## Generated Test Kernel Boot

Generated:

```text
dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
sha256=a21bb8924c910e9f180d7a033271e38a8219063e1a0ed71c7010d627de19c1e9
```

This image combines:

- LineageOS `20260627` MI8 boot parameters and ramdisk
- CaCam OS MI8 UVC kernel

It is valid for kernel testing and has already booted temporarily, but it does
not set `ro.usb.uvc.enabled=true`.

## Magisk Test Boot

The Magisk-patched MI8 boot image must be produced on the MI8 itself with:

```bash
./magisk/dipper-webcam/tools/patch-cacam-uvc-boot-with-magisk.sh \
  dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
```

Do not use a host-patched boot image unless it has been verified to contain
ARM64 Magisk binaries. A host patch using `x86_64` Magisk binaries would create
an image for the wrong architecture.

Generated on-device with Magisk `30.7`:

```text
dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627-magisk-v30.7-patched.img
sha256=686eba2afad0ffdb5e43a75d6de43c77fda3db4a34352ad37aa639fdf74d54c9
```

Next test requires a ROM build including the `0.1.9` overlay and pre-wake/retry
corrections, then host-side UVC enumeration proof with
`v4l2-ctl --list-devices`.
