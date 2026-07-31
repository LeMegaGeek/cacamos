# CaCam OS Xiaomi Webcam Addons

Source addons for exposing supported Xiaomi phones as standard USB webcams.

## 1.2.0

- Adds the complete dedicated CaCamOS port for the Xiaomi Mi 10 Pro (`cmi`),
  based on LineageOS 23.2 / Android 16.
- Publishes fourteen reproducible patches covering the device product,
  framework USB defaults, DeviceAsWebcam, the `sm8250` UVC/UAC2 gadget,
  SELinux, QTI USB HAL, Settings, ADB, recovery and the appliance package graph.
- Boots with CaCamOS branding into the persistent webcam interface, without a
  lock screen, setup wizard, generic launcher, browser, gallery or music app.
- Keeps the physical USB cable dedicated to standard UVC video and UAC2 audio,
  while authenticated maintenance ADB remains available over Wi-Fi.
- Advertises MJPEG 1280x720, 1024x576 and 1920x1080 at 15 and 30 FPS.
- Carries the asynchronous UVC request pipeline, disconnect recovery, hardware
  JPEG path and bidirectional 48 kHz USB audio established on the MI8.
- Adds exact-base and live-worktree patch verification plus a controlled
  ten-worker build profile that reserves six of the host's sixteen cores.
- Records the successful Windows interoperability test reported on the physical
  Xiaomi Mi 10 Pro.

## 1.1.0

- Extends the standard UVC webcam into a standard USB Audio Class 2 composite
  device, without BGOBS or host software.
- Exposes the Xiaomi Mi 8 microphone to Linux and Windows as **CaCamOS
  Microphone**, mono PCM at 48 kHz and 16 bits.
- Exposes the Xiaomi Mi 8 speakers as **CaCamOS Speakers**, accepting stereo
  PCM playback from Linux and Windows at 48 kHz and 16 bits.
- Keeps video, microphone and speaker functions on the same physical USB
  cable while retaining authenticated maintenance ADB over Wi-Fi.
- Adds a self-healing Android/tinyalsa bridge which survives USB removal,
  host stream closure and gadget re-enumeration without blocking the webcam
  service.
- Uses the standard composite IAD device class and an adaptive USB audio OUT
  endpoint so Windows can bind its built-in video and Audio Class 2 drivers
  without a CaCamOS host driver.
- Grants camera and microphone access as fixed appliance permissions and
  limits raw ALSA access to the dedicated DeviceAsWebcam SELinux domain.
- Handles the ALSA-sanitized `UAC2Gadget` card ID and grants the webcam domain
  access to Android's audio services, allowing the bridge to carry real audio.
- Includes the 1.0.1 Settings-to-webcam navigation improvement.

Qualified OTA. The final image passed physical video, microphone and speaker
tests on Linux and Windows using the hosts' built-in USB class drivers. Linux
qualification also covered all six advertised video modes with both audio
directions active, ten repeated opens, five USB resets and a two-minute
720p30 run.

```text
lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.1.0-dipper.zip
size=1068470898
sha256=26c95ecf7ba4886b55f64bfae298b9f799c91fc8a2ee25476abc8f936f4879ca
build_incremental=1785352812
```

## 1.0.1

- Adds a prominent **Return to webcam** action at the top of Settings, with
  French and English labels, so maintenance no longer leaves the user hunting
  for the dedicated camera interface.
- Returns to the existing DeviceAsWebcam task in one tap without restarting
  the phone or webcam process.
- Makes the persistent webcam notification explicitly say that tapping it
  returns to the webcam.
- Adds source, compiled-artifact and physical UI regression gates for the
  Settings-to-webcam path.
- Includes the CaCamOS boot animation, boot probe and privileged permission
  file in the reproducible patch series instead of relying on out-of-tree
  workspace files.
- Retains the complete standard-UVC behavior and physical qualification of
  1.0.0.

Release OTA:

```text
lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.1-dipper.zip
size=1068373381
sha256=551ce99f6aebc766b7a16b086d533580b4416aeb3875071052cb1bb71217a2d8
build_incremental=1785347654
```

## 1.0.0

- Delivers the first dedicated CaCamOS appliance for the Xiaomi Mi 8:
  CaCamOS-branded boot, automatic webcam preview, no lock screen or consumer
  setup, and no browser, gallery, music player or generic launcher.
- Exposes a standard UVC webcam on the physical USB cable. Stock OBS,
  Chromium/WebRTC, GStreamer and VLC work without BGOBS or network video.
- Keeps authenticated ADB maintenance on Wi-Fi while leaving USB dedicated to
  UVC and disabling legacy unauthenticated ADB-over-TCP.
- Advertises only MJPEG 1280x720, 1024x576 and 1920x1080 at 15 and 30 FPS.
  The former 360p and YUYV modes are removed.
- Queues a valid MJPEG warmup frame before `VIDIOC_STREAMON`, satisfying the
  short first-frame deadline used by stock OBS.
- Drains UVC control events on every bounded listener pass, fixing the lost
  wakeup that could freeze rapid stream close/reopen.
- Handles `ENODEV` and `ESHUTDOWN` as normal endpoint removal during cable and
  host reset cycles.
- Passes 100 rapid reopens, stock OBS at 30 FPS, WebRTC, GStreamer, VLC,
  3,600 intact 720p frames over two minutes, and five host USB resets.
- Adds complete appliance, recovery, controlled-build, host-application and
  runtime qualification gates across fourteen reproducible patches.

Qualified OTA:

```text
lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
size=1068308344
sha256=7ff904f2bd95bda315266ab7c40b5d1fa2c2a6a354c53c15ae0393761360e1ea
build_incremental=1785337449
```

## 0.7.0

- Publishes the physically qualified Xiaomi Mi 8 R13 OTA with reproducible
  source, patch, artifact and package-signature gates.
- Starts directly in the webcam interface without a lock screen, exposes UVC
  alone on the cable and restores secure ADB over Wi-Fi automatically.
- Fixes UVC streaming freezes, malformed MJPEG frames, color conversion, the
  former green band and front-camera landscape orientation.
- Advertises only the verified 360p, 720p and 1080p MJPEG modes plus 360p
  YUYV, each at 15 and 30 FPS.
- Delivers 18,000 intact 720p MJPEG frames over ten minutes and survives
  repeated USB remove/add cycles without restarting the phone or webcam
  process.
- Lets OBS Studio 32.2.0 on Linux detect USB removal and return when the source
  uses its direct `/dev/video0` node.
- Adds controlled two-job builds, memory protection, exact OTA verification,
  recovery-only installation and complete runtime qualification tools.
- Moves CaCamOS into its dedicated `LeMegaGeek/cacamos` repository and records
  all eight MI8 LineageOS patches.

Qualified OTA:

```text
lineage-22.2-20260727-UNOFFICIAL-CACAMOS-R13-dipper.zip
size=1223300465
sha256=efed9f1141514d1835bd8e48e6a5d7d04fa97fb0ab97083fd8df194f42c4a7a8
build_incremental=1785181771
```

Known limitation: after a USB disconnect/reconnect, OBS can later stop
receiving frames. Restarting OBS restores capture.

## 0.6.11

## Included Targets

- Xiaomi Mi 10 Pro (`cmi`), LineageOS `23.2`, addon `0.5.3`.
- Xiaomi Mi 8 (`dipper`), LineageOS `22.2`, addon `0.1.9`.
- Workspace helper: `tools/prepare-lineage-workspace.sh`.
- Connected-device audit helper: `tools/audit-connected-device.sh`.

## New in 0.6.11

- Adds a runtime memory watchdog to the MI8 gentle build wrapper. Future build
  attempts now stop automatically if `MemAvailable` drops below the configured
  safety threshold.
- Adds `--min-free-mem-mib` and `--watchdog-interval` options for tuning that
  safety stop.

## New in 0.6.10

- Tightens the MI8 gentle build wrapper so it reserves two CPU cores for the
  desktop by default when `taskset` is available.
- Adds `--reserve-cores` and `--cpu-set` options for explicit CPU affinity
  control before the next MI8 ROM build attempt.

## New in 0.6.9

- Adds the MI8 gentle build wrapper so the ROM build can be resumed only under
  acceptable memory/swap conditions, with one low-priority build job.

## New in 0.6.8

- Updates the MI8 addon to pre-wake DeviceAsWebcam before the USB gadget HAL
  pulls up UVC, and to retry service setup while the UVC video node appears.
- Records the next blocker from live testing: Linux detects the MI8 UVC
  interfaces as `18d1:4eee`, but the old path can let host `uvcvideo` probe
  before Android has opened `/dev/video3`.

## New in 0.6.7

- Updates the MI8 addon to ignore internal V4L2 nodes exposed by the Qualcomm
  display/camera/codec stack (`/dev/video0`, `/dev/video1`, `/dev/video2`,
  `/dev/video32`, `/dev/video33`).
- Records the live MI8 test result: UVC kernel bind succeeds, the QTI USB HAL
  accepts `uvc`, but DeviceAsWebcam currently falls back because it opens the
  internal `sde_rotator` node before this overlay correction is present.

## New in 0.6.6

- Adds a reproducible MI8 UVC boot-image generator that reuses the official
  LineageOS `dipper` boot ramdisk and replaces only the kernel with the CaCam
  OS UVC `Image.gz-dtb`.
- Adds a MI8 Magisk diagnostic module that sets `ro.usb.uvc.enabled=true` when
  used with a CaCam OS UVC kernel boot.
- Adds the current MI8 prep artifacts:
  `dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img` and
  `dist/CaCamOS-dipper-webcam-magisk-0.1.0.zip`.
- Confirms the MI8 kernel-only boot has UVC kernel options enabled; final USB
  webcam proof still waits on ADB authorization and host-side enumeration.

## New in 0.6.5

- Completed local `frameworks/base` sync for the `cmi` source preflight.
- Applied the CaCam OS `cmi` addon to a real local LineageOS `23.2` source
  checkout.
- `cmi` preflight now handles both pre-patch and already-patched source trees.
- `cmi` `verify-source-tree.sh` passes on the patched local source checkout.
- Adds `CURRENT_SOURCE_PREFLIGHT.md` with the current source evidence and the
  remaining build/flash/host webcam proof.

## New in 0.6.4

- Adds `--sync-webcam-deps` to fetch only the projects needed for source
  preflight and addon verification.
- Adds a non-destructive `cmi` preflight checker that runs `git apply --check`
  and validates DeviceAsWebcam, HAL, SELinux and kernel UVC pieces.
- Validated the `cmi` patch against a real partial LineageOS `23.2` source
  checkout.

## New in 0.6.3

- Adds device-specific local manifest generation for both `cmi` and `dipper`.
- Pins the matching LineageOS device tree, common tree, kernel and TheMuppets
  vendor repositories before `repo sync`.
- Keeps the MI8-first test path explicit without launching the large sync
  automatically.

## MI10 Pro

The `cmi` addon enables Android `DeviceAsWebcam` and
`ro.usb.uvc.enabled=true`. The checked LineageOS kernel already has UVC gadget
support, so the source verifier focuses on the Android product, HAL and SELinux
path.

## MI8

The `dipper` addon enables Android `DeviceAsWebcam`,
`ro.usb.uvc.enabled=true`, and the missing kernel UVC options:

```text
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

## Validation Status

The Xiaomi Mi 8 R13 OTA is installed and physically qualified. The Mi 10 Pro
source addon remains an audited source target and is not part of this release.
