# Current Xiaomi Mi 8 Audit

Audit date: 2026-07-29

## Qualified Build

The installed and qualified CaCamOS 1.0.0 OTA is:

```text
lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
size=1068308344
sha256=7ff904f2bd95bda315266ab7c40b5d1fa2c2a6a354c53c15ae0393761360e1ea
build_incremental=1785337449
```

All fourteen patches reproduce the audited LineageOS worktrees. Source,
compiled-payload, archive-integrity and whole-package-signature gates pass.

## Appliance State

The physical Xiaomi Mi 8 reports:

```text
model=CaCamOS MI 8 Webcam
brand=CaCamOS
cacamos_version=1.0.0
cacamos_appliance=true
setupwizard_mode=DISABLED
build_incremental=1785337449
usb_identity=18d1:4eed
usb_functions=UVC only
```

DeviceAsWebcam is the only HOME activity and opens automatically. There is no
active credential or lock screen. Consumer browser, gallery, music and generic
launcher packages are absent. Authenticated wireless ADB is enabled for
maintenance; legacy unauthenticated TCP ADB is disabled.

## Standard UVC Modes

The Linux `uvcvideo` driver sees:

| Format | Resolution | Frame rates |
| --- | --- | --- |
| MJPEG | 1280x720 | 15, 30 FPS |
| MJPEG | 1024x576 | 15, 30 FPS |
| MJPEG | 1920x1080 | 15, 30 FPS |

The former 360p and raw YUYV modes are absent.

## Runtime Qualification

The full mode matrix passed twice for 30 seconds per mode. The final exact
artifact then passed:

- 100 rapid UVC close/reopen cycles;
- Chromium WebRTC at 1280x720 and 29.30 FPS;
- GStreamer and VLC capture and decode;
- stock OBS at 1280x720 and 30.00 FPS without BGOBS;
- 3,600 intact 720p MJPEG frames in 120.264 seconds;
- five host USB resets followed by 300 intact frames each;
- unchanged phone boot ID and DeviceAsWebcam process across resets.

Every checked MJPEG frame had valid boundaries, decoded successfully and
remained within the cadence limit. No DeviceAsWebcam crash or ANR was found.

Evidence:

```text
dist/cacam-os-qualifications/20260729-v1-final-focus/20260729-185156-runtime
dist/cacam-os-qualifications/20260729-v1-warmup-full/20260729-181655-runtime
```

## Closed Failures

The previous OBS first-frame timeout is fixed by queueing a valid MJPEG warmup
frame before `VIDIOC_STREAMON`.

The previous rapid-reopen freeze is fixed by draining UVC control events on
every bounded listener pass, even when the old MI8 kernel loses an `EPOLLPRI`
wakeup.

USB endpoint removal now treats `ENODEV` and `ESHUTDOWN` as expected stream
termination and follows the normal cleanup path.

Physical preview checks confirm upright front-camera portrait and landscape,
correct colors and no green band. The accepted black portrait bars remain
inside the fixed 16:9 frame.

## Safety

Do not use Android's `svc usb resetUsbGadget` on this MI8 kernel. Use an
ordinary reconnect or host-side USB reset.

Installation is supported only through Lineage Recovery and ADB sideload. A
first move from LineageOS or CaCamOS 0.x must format data to remove legacy
credentials and user state.
