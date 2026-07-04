# CaCam OS Xiaomi Webcam Addons 0.6.11

Source addons for exposing supported Xiaomi phones as standard USB webcams.

## Included Targets

- Xiaomi Mi 10 Pro (`cmi`), LineageOS `23.2`, addon `0.5.3`.
- Xiaomi Mi 8 (`dipper`), LineageOS `22.2`, addon `0.1.9`.
- Workspace helper: `cacam-os/tools/prepare-lineage-workspace.sh`.
- Connected-device audit helper: `cacam-os/tools/audit-connected-device.sh`.

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

Both source addons apply cleanly to mini LineageOS source trees reconstructed
from official LineageOS GitHub sources. Real completion still requires flashing
the resulting build and proving host-side UVC enumeration with:

```bash
v4l2-ctl --list-devices
```
