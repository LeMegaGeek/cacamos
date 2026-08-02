# CaCamOS 1.2.0 for Xiaomi Mi 10 Pro (`cmi`)

Dedicated webcam OS release for LineageOS 23.2 / Android 16.

## Clean Installation Required

On the first move from LineageOS or CaCamOS 0.x, use **Format data / factory
reset** in Lineage Recovery. ADB sideload updates the OS partitions but does
not erase `/data`. Skipping the format preserves previous applications,
accounts, credentials and notifications.

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
  `6543738bfcc6ce4d9bce233677f8b68919cbf324e2843c42cb65f956d2abc649`.
- The final OTA is installed on a physical MI10 Pro and enumerates as
  `CaCamOS Webcam`, with standard UVC 1.5 video and UAC2 audio on Linux.
- 1280x720, 1024x576 and 1920x1080 at 30 FPS were captured successfully. The
  1080p test ran for 120 seconds without a freeze or dropped stream.
- The 48 kHz mono USB microphone recorded successfully. USB speaker playback
  was confirmed by an acoustic 1 kHz return recording through the phone.
- Appliance startup, persistent wireless ADB, UVC-only cable ownership, HOME
  webcam preview, removal of consumer applications and credential clearing all
  passed before and after an unattended reboot.
- The physical MI10 Pro data partition was reformatted as F2FS for the final
  clean qualification. Runtime verification reports zero third-party packages;
  no previous application or account remains.
- After that clean format, simultaneous 1080p/30 video, USB microphone capture
  and USB speaker playback passed again. The speaker return produced a
  continuous 1 kHz signal for the complete 12-second playback interval.
- A host USB reset was followed by successful video, microphone and speaker
  recovery. A post-reset 1024x576 stream returned to 29.97 FPS.
- The installed recovery partition exactly matches the CaCamOS recovery image
  embedded in the OTA, so later CaCamOS packages use the matching trust store.
- Physical Windows interoperability on this MI10 Pro remains to be recorded.

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
