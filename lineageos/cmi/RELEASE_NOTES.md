# CaCam OS cmi Webcam Addon 0.5.3

Xiaomi Mi 10 Pro (`cmi`) LineageOS integration for standard USB webcam mode.

## Included

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

## Expected Result

After building and flashing a LineageOS image with this patch, the Mi 10 Pro can
be selected by a PC as a regular USB Video Class webcam. OBS should use it as a
normal Video Capture Device, without BGOBS and without network streaming.

## Known Limits

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
