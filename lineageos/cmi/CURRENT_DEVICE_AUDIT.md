# Current Mi 10 Pro Audit

Audit date: 2026-07-01

Connected device:

```text
ro.product.device=cmi
ro.product.model=Mi 10 Pro
ro.lineage.version=23.2-20260626-NIGHTLY-cmi
ro.build.version.release=16
ro.boot.verifiedbootstate=orange
SELinux=Enforcing
```

Observed normal-boot USB state:

```text
ro.usb.uvc.enabled=<unset>
sys.usb.config=adb
sys.usb.state=<unset>
sys.usb.configfs=2
```

Kernel config from `/proc/config.gz`:

```text
CONFIG_MEDIA_USB_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

Installed package:

```text
package:com.android.DeviceAsWebcam
```

Video nodes:

```text
/dev/video0
/dev/video1
/dev/video32
/dev/video33
```

USB services:

```text
android.hardware.usb-service.qti
android.hardware.usb.gadget-service.qti
SELinux domain: u:r:vendor_hal_usb_qti:s0
```

Compiled SELinux policy:

```text
vendor_hal_usb_qti is in hal_usb_gadget_server
hal_usb_gadget_server can read usb_uvc_enabled_prop
```

Runtime test notes:

```text
svc usb setFunctions uvc,adb
result: Android accepts the request, the shell command is killed, and USB falls
back to adb. The host still does not enumerate a UVC webcam on the stock
Nightly because ro.usb.uvc.enabled is unset.
```

Temporary Magisk test:

```text
Patched boot: lineage-23.2-20260626-nightly-cmi-boot-magisk-v30.7-patched.img
Root helper during temporary boot: /debug_ramdisk/su
```

Conclusion:

The attached LineageOS `cmi` build already contains the kernel pieces,
`DeviceAsWebcam`, the QTI gadget HAL service, and the SELinux permission that
lets the gadget HAL read `ro.usb.uvc.enabled`. The missing normal-boot piece is
still the product/vendor property itself:

```text
ro.usb.uvc.enabled=true
```

The CaCam OS source addon therefore keeps the fix at ROM build level: include
`DeviceAsWebcam`, set `ro.usb.uvc.enabled=true` for `cmi`, and verify that the
source tree's QTI USB gadget HAL supports `GadgetFunction::UVC` before building.
