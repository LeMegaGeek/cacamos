# CaCam OS MI8 Webcam Magisk Test

This is a runtime test module for Xiaomi Mi 8 (`dipper`) on LineageOS `22.2`.

It only sets:

```text
ro.usb.uvc.enabled=true
```

with Magisk `resetprop` early at boot. It does not add UVC kernel support by
itself. For MI8, use it only with a CaCam OS boot image whose kernel contains:

```text
CONFIG_MEDIA_USB_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

The current test image was built from the installed LineageOS build:

```text
22.2-20260627-NIGHTLY-dipper
```

## Test Flow

1. Patch the matching CaCam OS UVC boot image with Magisk on the MI8:

   ```bash
   ./magisk/dipper-webcam/tools/patch-cacam-uvc-boot-with-magisk.sh \
     dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
   ```

2. Temporarily boot the patched image printed by the script:

   ```bash
   ./magisk/dipper-webcam/tools/temporary-boot-patched.sh \
     dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627-magisk-v30.7-patched.img
   ```

3. Once Android is up and ADB is authorized, install this module:

   ```bash
   ./magisk/dipper-webcam/install-via-adb.sh
   ```

4. Reboot again with the same temporary boot image so `post-fs-data.sh` runs
   before the USB gadget HAL decides whether UVC is allowed.

5. Verify:

   ```bash
   ./lineageos/dipper/tools/verify-webcam.sh
   ```

Final success still requires host-side enumeration:

```bash
v4l2-ctl --list-devices
```

## Safety

The module exits without changing anything when `ro.product.device` is not
`dipper`.

This is a diagnostic path. The clean target remains a LineageOS build with the
CaCam OS source addon, where both the property and kernel config are present
from boot without Magisk.
