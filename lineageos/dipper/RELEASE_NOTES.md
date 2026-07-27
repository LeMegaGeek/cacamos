# CaCam OS dipper Webcam Addon

Xiaomi Mi 8 (`dipper`) LineageOS integration for standard USB webcam mode.

## 0.2.0 - R13

- Adds the verified R13 OTA with UVC-only cable policy, persistent
  ADB over Wi-Fi, direct-boot webcam startup and automatic preview launch.
- Keeps the UVC listener and gadget fd alive across a physical cable
  disconnect, tears down only the active stream and restores control-event
  polling for the next host enumeration.
- Releases the bound preview before stopping the foreground service when the
  gadget node is actually removed, so Android can complete native teardown and
  restart cleanly.
- Corrects the front-camera landscape transform from sensor orientation plus
  device orientation to sensor orientation minus device orientation. Portrait
  output remains unchanged and the phone controls use the matching physical
  transform.
- Uses a 320-request UVC pool with 64 initial empty requests, retaining enough
  queue depth for stable isochronous transfers without adding the former
  20-millisecond empty-packet delay.
- Retains each completed V4L2 frame on its final USB request and returns it to
  Android only from the USB completion callback.
- Enforces the negotiated 15 FPS cadence at the ImageReader boundary when the
  MI8 legacy camera HAL continues producing 30 FPS.
- Bounds camera, capture-session and encoded-buffer waits, rejects callbacks
  from obsolete stream generations and returns failed buffers to their pool.
- Removes a native shutdown lock inversion, makes listener state atomic,
  orders V4L2 buffer cleanup before fd closure and suppresses duplicate camera
  stream stops.
- Makes V4L2-node monitoring nonblocking and releases the delayed USB
  `SET_INTERFACE` request when native stream initialization fails.
- Stops the unused ADB FunctionFS USB transport in UVC-only mode without
  stopping TCP/TLS ADB over Wi-Fi.
- Converts the MI8 Android 4:2:0 buffers using their real dimensions and plane
  strides, restores output strides before letterboxing and contains libjpeg
  failures.
- Separates stream and UI rotation formulas for front and rear cameras while
  keeping the accepted fixed 16:9 portrait bars.
- Advertises only the MI8 rates supported by the audited camera pipeline:
  15 and 30 FPS. It no longer claims 2, 10, 50 or 60 FPS.
- Adds mandatory reproducible-patch, source, compiled-artifact, OTA-signature
  and raw-MJPEG gates.
- Builds the signed R13 release with incremental `1785181771` and SHA-256
  `efed9f1141514d1835bd8e48e6a5d7d04fa97fb0ab97083fd8df194f42c4a7a8`.

R13 physically validates all advertised MJPEG and YUYV modes at 15 and 30 FPS,
including 18,000 intact 720p frames over ten minutes. It starts automatically
without a lock screen, restores wireless ADB, fixes front-camera landscape
orientation, retains correct colors and survives repeated USB remove/add
cycles without restarting the phone or webcam process.

On OBS Studio 32.2.0 for Linux, configure the source with the direct capture
node, such as `/dev/video0`. OBS then associates udev remove/add events with
the source when USB returns. A `/dev/v4l/by-id/...` source path does not trigger
this OBS reconnection path.

Known limitation: after a cable disconnect/reconnect, OBS can later stop
receiving frames. Restarting OBS restores capture.

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
- Enables the MI8 UVC gadget in the device-specific kernel config fragment with
  `CONFIG_USB_CONFIGFS_F_UVC=y`. The host-side `CONFIG_USB_VIDEO_CLASS` driver
  is intentionally not required.
- Adds source-tree install and verification scripts.
- Adds a conservative LineageOS build wrapper:
  `tools/build-lineage-gentle.sh`. It checks available memory/swap, uses two
  build jobs, reserves two CPU cores through `taskset` when available, and runs
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
