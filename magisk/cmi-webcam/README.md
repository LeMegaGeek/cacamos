# CaCam OS Mi 10 Pro Webcam Magisk Module

This is an optional runtime variant for a rooted Xiaomi Mi 10 Pro (`cmi`).

It is useful when the current LineageOS build already contains:

- `CONFIG_USB_CONFIGFS_F_UVC=y`
- `com.android.DeviceAsWebcam`

but does not set:

```text
ro.usb.uvc.enabled=true
```

The module sets that read-only property early at boot with Magisk `resetprop`.
It does not force the USB function to `uvc`; Android's `DeviceAsWebcam` service
and USB UI remain responsible for selecting webcam mode.

On the attached `23.2-20260626-NIGHTLY-cmi` test phone, temporary Magisk boot
exposes root through `/debug_ramdisk/su`. The scripts handle both that path and
the usual `su` path.

## Install

If the phone is already rooted with Magisk, install the module ZIP from Magisk,
or use:

```bash
./magisk/cmi-webcam/install-via-adb.sh
```

2. Reboot.
3. Run:

```bash
adb shell getprop ro.usb.uvc.enabled
adb shell pm list packages com.android.DeviceAsWebcam
```

4. Plug the phone into the host and select Webcam mode if Android exposes it.

## Verify

From the CaCam repository:

```bash
./lineageos/cmi/tools/verify-webcam.sh
```

On Linux host:

```bash
v4l2-ctl --list-devices
```

OBS should then list the phone as a regular Video Capture Device.

## Safety

The module exits without changing anything when `ro.product.device` is not
`cmi`.

## First Magisk Install

If the phone is not rooted yet, first obtain a matching `boot.img`.

For the exact installed build:

```bash
./magisk/cmi-webcam/tools/download-lineage-boot.sh --current
```

If LineageOS no longer publishes that build, this command refuses to continue.
Use `--latest` only if the phone has first been updated to that same latest
LineageOS build.

To prepare the latest official LineageOS build and matching Magisk-patched boot
image without flashing anything:

```bash
./magisk/cmi-webcam/tools/prepare-lineage-magisk-test.sh --latest
```

Add `--with-rom` to also download and verify the full signed ROM ZIP that would
be needed to update the phone:

```bash
./magisk/cmi-webcam/tools/prepare-lineage-magisk-test.sh --latest --with-rom
```

Then patch the boot image:

```bash
./magisk/cmi-webcam/tools/patch-boot-with-magisk.sh dist/magisk-test/<boot>.img
```

For a non-destructive test, boot it temporarily:

```bash
./magisk/cmi-webcam/tools/temporary-boot-patched.sh dist/magisk-test/<patched-boot>.img
```

The temporary boot script refuses to continue when the patched image filename
contains a LineageOS build date that does not match the installed
`ro.lineage.version`. Do not boot or flash a patched boot image from a
different LineageOS build date than the one installed on the phone.

## Current Limit

The runtime Magisk path is diagnostic. On the attached phone, forcing
`ro.usb.uvc.enabled=true` after boot was not enough to prove host-side UVC
enumeration. The clean target remains a LineageOS build where the property is
present from boot through the CaCam OS source addon.
