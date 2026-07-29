# CaCamOS 1.0.0 Acceptance Record

Status date: 2026-07-29

Status: release-qualified on the physical Xiaomi Mi 8.

## Release Artifact

```text
release=lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
source=out/target/product/dipper/lineage_dipper-ota.zip
size=1068308344
sha256=7ff904f2bd95bda315266ab7c40b5d1fa2c2a6a354c53c15ae0393761360e1ea
build_incremental=1785337449
lineage=22.2-20260729-UNOFFICIAL-dipper
```

The installed `libjni_deviceAsWebcam.so` SHA-256 is:

```text
947c152f3e85f79d9f9ac508147a50422189f54454d16c98268e3c239bce3d04
```

It matches the final compiled artifact.

## Acceptance Matrix

| Requirement | Evidence | Status |
| --- | --- | --- |
| Fourteen patches reproduce the audited LineageOS worktrees | `verify-patch-series.sh --match-worktrees` | Passed |
| Product identifies as `CaCamOS MI 8 Webcam`, appliance 1.0.0 | Compiled properties and physical device | Passed |
| CaCamOS boot branding replaces the Lineage boot animation | Compiled target payload and physical boot | Passed |
| Browser, gallery, music player and generic launcher are absent | Compiled target and runtime package gates | Passed |
| DeviceAsWebcam is the persistent direct-boot HOME activity | Compiled APK and runtime activity state | Passed |
| Startup opens the preview with no lock or setup flow | Physical device | Passed |
| The cable composition is exactly UVC | USB HAL, ConfigFS and host enumeration | Passed |
| Secure ADB remains available over Wi-Fi | Runtime transport and policy gates | Passed |
| Legacy unauthenticated ADB-over-TCP is disabled | Runtime properties | Passed |
| Recovery exposes its cable ADB maintenance channel | Physical installation | Passed |
| Kernel includes the UVC gadget and bounded frame lifecycle | Compiled kernel config, symbols and runtime | Passed |
| MJPEG 720p, 1024x576 and 1080p advertise only 15/30 FPS | Descriptors and host enumeration | Passed |
| Every advertised MJPEG mode delivers intact frames at cadence | Full physical stream matrix | Passed |
| Front-camera portrait and landscape are upright with correct colors | Physical host preview | Passed |
| Chromium WebRTC, GStreamer and VLC use the standard camera | Application qualification | Passed |
| Stock OBS captures with its bundled V4L2 source, without BGOBS | 252 frames, 8.5 seconds, 30 FPS | Passed |
| 100 rapid close/reopen cycles preserve every `STREAMON` | Rapid-reopen regression | Passed |
| Sustained 720p capture remains live and intact | 3,600 frames, 120.264 seconds, 29.94 FPS | Passed |
| Five host USB resets recover without a phone or service restart | Runtime qualification | Passed |
| OTA archive integrity and whole-package signature are valid | `verify-build-artifacts.sh` | Passed |
| Exact OTA and checksum are published publicly | GitHub release `v1.0.0` | Passed |

## Root Causes Closed

The Android 4.9 V4L2 path could lose the UVC control wakeup after a rapid
close/reopen. The listener now processes control events on every bounded
66-millisecond pass, even without a new edge notification.

Stock OBS waits only about 190 milliseconds for its first frame, while the MI8
camera HAL needs about 590 milliseconds to deliver the first real image.
CaCamOS now queues a valid black MJPEG warmup frame before camera startup and
before `VIDIOC_STREAMON`.

When the host removes the USB endpoint, `VIDIOC_QBUF` can return `ENODEV` or
`ESHUTDOWN`. CaCamOS classifies this as an expected endpoint stop and performs
the normal stream cleanup.

## Physical Evidence

Final exact-artifact run:

```text
dist/cacam-os-qualifications/20260729-v1-final-focus/20260729-185156-runtime
```

This run passed appliance startup, USB policy, 100 rapid reopens, WebRTC,
GStreamer, VLC, stock OBS, a two-minute sustained capture and five USB resets.

Full six-mode run:

```text
dist/cacam-os-qualifications/20260729-v1-warmup-full/20260729-181655-runtime
```

It passed each 15/30 FPS mode twice for 30 seconds, 18,000 intact 720p frames
over 603.810 seconds and five host USB resets. The only later source change was
the expected endpoint-removal log classification described above.

## Installation

Installation is supported only through Lineage Recovery and ADB sideload. For
the first move from LineageOS or CaCamOS 0.x, format data before sideloading;
this erases legacy credentials and user state.

After first boot, connect Wi-Fi once for authenticated wireless ADB
maintenance. The physical USB cable remains UVC-only.

Do not use Android's `svc usb resetUsbGadget` command on this MI8 kernel.
Qualification uses ordinary reconnects and host-side USB resets.
