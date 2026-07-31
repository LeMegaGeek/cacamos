# CaCamOS 1.2.0 for Xiaomi Mi 10 Pro (`cmi`)

Dedicated webcam OS source integration for LineageOS 23.2 / Android 16.

## Included

- CaCamOS appliance branding and boot animation.
- Automatic startup in the persistent DeviceAsWebcam preview.
- No lock screen, consumer setup flow, generic launcher, browser, gallery or
  music application.
- Standard UVC webcam plus UAC2 microphone and speakers on one physical USB
  cable, without BGOBS or a host driver.
- Authenticated wireless ADB for maintenance; USB ADB is deliberately disabled
  during normal operation.
- MJPEG 1280x720, 1024x576 and 1920x1080 at 15 and 30 FPS.
- Hardware JPEG encoding, bounded frame pacing, warmup frame, reliable stream
  restart and robust `sm8250` UVC request/disconnect handling.
- Persistent wireless-debugging and no-lock defaults, recovery ADB and startup
  diagnostics.
- A fourteen-patch reproducible source series tied to exact LineageOS base
  revisions.
- A controlled ten-worker build profile that leaves six cores available on the
  sixteen-core host.

## Validation

- Every patch recreates the audited local Android worktrees exactly.
- The complete source verifier passes for `cmi`.
- The complete signed block OTA builds successfully and passes archive,
  device-target, appliance-property and webcam-artifact verification. Its
  SHA-256 is
  `1584bb975ec0c496f9cb4c114ea77af688b7808b9bae1f422da604b88245e146`.
- Physical MI10 Pro installation and standard Windows/Linux interoperability
  remain pending.

## Previous 0.5.3 Addon

Xiaomi Mi 10 Pro (`cmi`) LineageOS integration for standard USB webcam mode.

### Included

- Enables Android/LineageOS `DeviceAsWebcam`.
- Advertises UVC support at boot with `ro.usb.uvc.enabled=true`.
- Adds a `cmi` runtime resource overlay for future camera physical-ID tuning.
- Verifies that the QTI USB gadget HAL supports `GadgetFunction::UVC`, links
  `uvc.0`, and gates webcam mode on `ro.usb.uvc.enabled`.
- Verifies that `hal_usb_gadget_server` can read `usb_uvc_enabled_prop`.
- Updates the attached Mi 10 Pro audit to
  `23.2-20260626-NIGHTLY-cmi`.
- Updates the Magisk test helpers for the observed temporary-root path
  `/debug_ramdisk/su`.
- Adds workspace local manifest generation for the MI10 Pro device tree, common
  tree, kernel and TheMuppets vendor blobs.
- Adds a non-destructive preflight checker for real LineageOS sources.
- Confirms the patch applies cleanly to a partial real `lineage-23.2` `cmi`
  source checkout with HAL, SELinux, kernel and vendor pieces present.
- Completes local `frameworks/base` source sync for the preflight.
- Applies the addon to a real local `lineage-23.2` `cmi` checkout and verifies
  the patched source tree.
- Allows the preflight checker to validate an already-patched source tree.
- Adds `CURRENT_SOURCE_PREFLIGHT.md` with current source-side proof and the
  remaining runtime proof steps.

### Expected Result

After building and flashing a LineageOS image with this patch, the Mi 10 Pro can
be selected by a PC as a regular USB Video Class webcam. OBS should use it as a
normal Video Capture Device, without BGOBS and without network streaming.

### Known Limits

- Not a flashable ROM ZIP yet; this is a source-tree addon patch.
- The stock `23.2-20260626-NIGHTLY-cmi` still has
  `ro.usb.uvc.enabled=<unset>`, so it does not enumerate as a webcam without a
  rebuilt ROM or a successful rooted runtime test.
- The Magisk module path requires root/Magisk. Temporary boot of a matching
  Magisk-patched `20260626` boot image exposes root as `/debug_ramdisk/su`.
- Physical camera labels are not tuned yet. A real `cmi` camera dump is needed
  before mapping wide, ultra-wide and telephoto IDs precisely.
- Full validation still requires a flashed Mi 10 Pro build and host-side webcam
  tests with `v4l2-ctl --list-devices` and OBS.
