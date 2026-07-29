# Current CaCamOS MI8 Status

Status date: 2026-07-29

## Release

CaCamOS 1.0.0 is built, installed and physically qualified on the Xiaomi Mi 8
(`dipper`).

```text
release=lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
source=out/target/product/dipper/lineage_dipper-ota.zip
size=1068308344
sha256=7ff904f2bd95bda315266ab7c40b5d1fa2c2a6a354c53c15ae0393761360e1ea
build_incremental=1785337449
```

The complete fourteen-patch series reproduces the audited LineageOS
worktrees. Source, compiled payload, archive-integrity and package-signature
gates pass.

## Dedicated Appliance

The installed release proves:

- `ro.cacamos.version=1.0.0` and `ro.cacamos.appliance=true`;
- CaCamOS product and boot branding;
- automatic startup into the DeviceAsWebcam preview;
- no lock screen, consumer setup flow or generic launcher;
- no browser, gallery or music player;
- exactly UVC on the physical USB cable;
- authenticated ADB maintenance over Wi-Fi, with legacy open TCP ADB disabled;
- the standard Linux `uvcvideo` driver and USB identity `18d1:4eed`.

## UVC Modes

Only real MJPEG camera modes are advertised:

| Resolution | Frame rates |
| --- | --- |
| 1280x720 | 15, 30 FPS |
| 1024x576 | 15, 30 FPS |
| 1920x1080 | 15, 30 FPS |

The old 360p and YUYV modes are intentionally absent.

## Stability

CaCamOS 1.0.0 queues a valid black MJPEG frame before `VIDIOC_STREAMON`.
Applications with a short initial-frame deadline, including stock OBS, can
therefore open the camera while the MI8 camera HAL produces its first frame.

The UVC listener also drains control events on every bounded listener pass.
This prevents a lost `EPOLLPRI` edge from freezing a rapid stream restart.
Endpoint removal returns through the normal disconnect path instead of being
reported as a camera failure.

Final exact-artifact qualification passed:

- 100 rapid close/reopen cycles, five real frames per cycle;
- Chromium WebRTC: 120 frames at 29.30 FPS;
- GStreamer and VLC decode;
- stock OBS: 252 frames over 8.5 seconds at 30.00 FPS;
- 3,600 intact 1280x720 frames over 120.264 seconds at 29.94 FPS;
- five host USB resets, each followed by 300 intact frames;
- unchanged phone boot ID and DeviceAsWebcam process across reset tests;
- no DeviceAsWebcam crash, ANR or frame-integrity failure.

The full six-mode matrix was also qualified twice for 30 seconds per mode on
the same streaming implementation. The final change after that matrix only
classified `ENODEV` and `ESHUTDOWN` as expected endpoint removal.

Runtime evidence:

```text
dist/cacam-os-qualifications/20260729-v1-final-focus/20260729-185156-runtime
dist/cacam-os-qualifications/20260729-v1-warmup-full/20260729-181655-runtime
```

## Image

Physical checks confirm upright front-camera video in portrait and landscape,
correct colors and no green band. Portrait keeps the accepted black side bars
inside the fixed 16:9 UVC frame.

## Installation Policy

Use Lineage Recovery and `adb sideload` only. A first move from ordinary
LineageOS or CaCamOS 0.x must include a data format so legacy lock and user
state cannot override appliance defaults.

Do not run `svc usb resetUsbGadget` on this MI8 kernel. Use ordinary cable
reconnects or a host-side USB reset.
