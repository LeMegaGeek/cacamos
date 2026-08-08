# CaCamOS for Xiaomi Mi 10 Pro (`cmi`)

## 1.2.1

- Explicitly puts the display to sleep after 30 seconds without interaction,
  including when Android's ordinary window timeout is held awake elsewhere.
- Keeps double-tap-to-wake enabled so the webcam interface can be restored
  without using a physical button.
- Releases the local camera preview while the display is off. An open host UVC
  stream remains active; with no host stream, the camera can become idle too.
- Adds read-only ALSA controls for the host microphone and speaker stream
  states.
- Starts Android microphone capture and speaker playback only while the host
  has opened the corresponding UAC2 endpoint. This removes the permanent
  `AudioIn` wake lock present in 1.2.0 while the microphone is unused.
- Keeps the standard UVC/UAC2 identity, resolutions, frame rates and audio
  formats from 1.2.0 unchanged.
- Keeps recovery ADB available on appliance builds and no longer aborts a
  sideload when the optional `/cache` partition is unavailable or damaged.

Signed OTA:

```text
lineage-23.2-20260803-UNOFFICIAL-CACAMOS-1.2.1-cmi.zip
size=1422040935
sha256=7f82397716a3138699764ba072446977f45cdda893d9c4aa7419659268ccc003
build_incremental=1785781560
```

Physical qualification on the MI10 Pro passed the 30-second display sleep,
double-tap wake, idle camera and audio shutdown, 2,400-frame UVC/display-off
run, 60-second 720p30 integrity run, 1080p30 capture, 20 rapid UVC reopen
cycles, and simultaneous 720p30 microphone/speaker round trip. The complete
record is in [`V1_2_1_ACCEPTANCE.md`](V1_2_1_ACCEPTANCE.md).

## 1.2.0

Dedicated webcam OS release for LineageOS 23.2 / Android 16.

### Clean Installation Required

On the first move from LineageOS or CaCamOS 0.x, use **Format data / factory
reset** in Lineage Recovery. ADB sideload updates the OS partitions but does
not erase `/data`. Skipping the format preserves previous applications,
accounts, credentials and notifications.

### Included

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

### Validation

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

### Previous 0.5.3 Addon

Xiaomi Mi 10 Pro (`cmi`) LineageOS integration for standard USB webcam mode.

#### Included

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

#### Expected Result

After building and flashing a LineageOS image with this patch, the Mi 10 Pro can
be selected by a PC as a regular USB Video Class webcam. OBS should use it as a
normal Video Capture Device, without BGOBS and without network streaming.

#### Known Limits

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
