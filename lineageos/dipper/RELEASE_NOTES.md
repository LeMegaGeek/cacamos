# CaCam OS dipper Webcam Addon

Xiaomi Mi 8 (`dipper`) LineageOS integration for standard USB webcam mode.

## Unreleased

- Captures the current LineageOS working tree as a reproducible patch series.
- Defaults the MI8 to UVC-only after user unlock, without requiring ADB in the
  active USB composition.
- Includes the kernel and DeviceAsWebcam negotiation changes that make Linux
  enumerate the phone and let OBS receive a continuous stream.
- Queues the first camera frame before completing `STREAMON`, avoiding OBS's
  first-frame timeout.
- Keeps the current visual defects documented: 90-degree rotation, incorrect
  colors and a green band.

## 0.1.9

## Included

- Enables Android/LineageOS `DeviceAsWebcam`.
- Advertises UVC support at boot with `ro.usb.uvc.enabled=true`.
- Starts in Webcam mode by default on normal boot by setting
  `persist.sys.usb.config=uvc,adb`, then pre-warming `DeviceAsWebcam` before the
  host enumerates UVC.
- Adds a `dipper` runtime resource overlay for future camera physical-ID tuning.
- Tells DeviceAsWebcam to ignore MI8 internal V4L2 nodes that are not the UVC
  gadget (`sde_rotator`, camera request manager, sync and codec nodes). This
  prevents it from opening `/dev/video0` and failing on UVC events.
- Pre-warms DeviceAsWebcam just before the USB gadget HAL pulls up UVC, and
  lets the foreground service retry briefly while the UVC `/dev/videoX` node is
  being created. This avoids the Linux host probing UVC before Android is
  listening for UVC setup events.
- Enables MI8 kernel UVC pieces in the device-specific kernel config fragment:
  `CONFIG_MEDIA_USB_SUPPORT=y`, `CONFIG_USB_VIDEO_CLASS=y` and
  `CONFIG_USB_CONFIGFS_F_UVC=y`.
- Adds source-tree install and verification scripts.
- Adds a conservative LineageOS build wrapper:
  `tools/build-lineage-gentle.sh`. It checks available memory/swap, uses one
  build job, reserves two CPU cores through `taskset` when available, and runs
  at low CPU/IO priority for Denis' desktop.
- Adds a runtime memory watchdog to the MI8 build wrapper. If available memory
  drops below the configured threshold, the wrapper stops the build instead of
  letting the desktop become unusable.
- Adds an ADB/host verification script for the first MI8 test session.
- Adds workspace local manifest generation for the MI8 device tree, common tree,
  kernel and TheMuppets vendor blobs.
- Uses the updated workspace helper with source-only webcam dependency sync.
- Carries the common CaCam OS workspace documentation and packaging updates.
- Adds a reproducible kernel-only test boot generator:
  `tools/build-uvc-boot-image.sh`.
- Adds the MI8 Magisk diagnostic module path for setting
  `ro.usb.uvc.enabled=true` while testing a CaCam OS UVC kernel boot.

## Expected Result

After building and flashing a LineageOS image with this patch, the MI8 can be
selected by a PC as a regular USB Video Class webcam. OBS should use it as a
normal Video Capture Device.

## Known Limits

- Not a flashable ROM ZIP yet; this is a source-tree addon patch.
- Kernel-only test boot proves the UVC kernel side, but does not replace the
  full ROM build.
- Kernel-only MI8 testing reaches `uvc_function_bind`. With internal V4L2 nodes
  temporarily blocked, DeviceAsWebcam selects the real gadget node
  `/dev/video3` and Linux sees `18d1:4eee` as a UVC device, but the host probe
  still races ahead of the service on the old framework path. This release adds
  the pre-wake/retry source fix for the next ROM build.
- Full validation still requires a flashed build with this overlay and
  host-side `v4l2-ctl --list-devices` proof.
- Physical camera labels are not tuned yet. A real `dipper` camera dump is
  needed before mapping camera IDs precisely.
