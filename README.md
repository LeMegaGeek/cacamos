# CaCam OS

CaCam OS is the ROM-side track for exposing supported Android phones as real
USB webcams.

The current Xiaomi Mi 8 runtime state and the next image-pipeline work are
tracked in [`CURRENT_STATUS.md`](CURRENT_STATUS.md).

Unlike the Play Store CaCam app, this path targets the Android USB gadget stack:
the host computer should see a standard USB Video Class camera.

## Xiaomi Mi 8 Release

CaCamOS 0.7.0 includes the physically qualified MI8 R13 OTA:

```text
lineage-22.2-20260727-UNOFFICIAL-CACAMOS-R13-dipper.zip
sha256=efed9f1141514d1835bd8e48e6a5d7d04fa97fb0ab97083fd8df194f42c4a7a8
```

Release and download:
<https://github.com/LeMegaGeek/cacamos/releases/tag/v0.7.0>

```bash
git clone https://github.com/LeMegaGeek/cacamos.git
cd cacamos
```

## Targets

Current source targets:

- Xiaomi Mi 10 Pro, codename `cmi`, LineageOS `23.2`
- Xiaomi Mi 8, codename `dipper`, LineageOS `22.2`

Use the LineageOS source addons for clean ROM builds:

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineageos
./lineageos/dipper/tools/install-into-lineage.sh /path/to/lineageos
```

Prepare or inspect a LineageOS workspace with:

```bash
./tools/prepare-lineage-workspace.sh dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

For a real build workspace, initialize it, write the local manifest, then sync:

```bash
./tools/prepare-lineage-workspace.sh --init dipper /home/denis/Documents/Denis/dev/lineage-dipper
./tools/prepare-lineage-workspace.sh --local-manifest dipper /home/denis/Documents/Denis/dev/lineage-dipper
./tools/prepare-lineage-workspace.sh --sync dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

The local manifest pins the matching LineageOS device tree, common tree, kernel
and TheMuppets vendor blobs for the selected device.

For preflight checks without the full ROM tree, use:

```bash
./tools/prepare-lineage-workspace.sh --sync-webcam-deps cmi /home/denis/Documents/Denis/dev/lineage-cmi
./lineageos/cmi/tools/check-lineage-source-preflight.sh /home/denis/Documents/Denis/dev/lineage-cmi
```

When a phone is connected, collect a non-destructive audit with:

```bash
./tools/audit-connected-device.sh
```

Use the Magisk modules only for diagnostics:

- `cmi`: works on a rooted build that already contains `DeviceAsWebcam` and the
  UVC kernel options.
- `dipper`: requires a CaCam OS MI8 UVC boot image first, because stock MI8
  LineageOS still lacks the UVC kernel options.

The attached Mi 10 Pro audit showed:

- kernel UVC options: present
- `com.android.DeviceAsWebcam`: present
- QTI USB gadget HAL service: present
- SELinux read access for `usb_uvc_enabled_prop`: present
- `ro.usb.uvc.enabled`: missing
- LineageOS checked: `23.2-20260626-NIGHTLY-cmi`
- temporary Magisk root: works with a matching patched boot image through
  `/debug_ramdisk/su`

So the first CaCam OS target is deliberately narrow: enable Android's existing
Device-as-Webcam path on `cmi`.

The MI8 source audit showed:

- official LineageOS build checked: `22.2-20260627`
- QTI USB gadget HAL UVC support: present
- SELinux read access for `usb_uvc_enabled_prop`: present
- `CONFIG_USB_CONFIGFS_F_UVC`: missing in stock kernel config

So the `dipper` addon also patches the device-specific kernel config fragment.
`CONFIG_USB_VIDEO_CLASS` is not required here: it is the host-side webcam
driver, while CaCamOS uses the UVC gadget function.

Current MI8 test artifacts:

```text
dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627-magisk-v30.7-patched.img
dist/CaCamOS-dipper-webcam-magisk-0.1.0.zip
dist/CaCamOS-dipper-webcam-magisk-prep-20260627-0.1.0.zip
```

The kernel-only and Magisk-patched boot tests have verified the MI8 UVC kernel
path and `ro.usb.uvc.enabled=true`. Live testing then found two ROM-side fixes:
DeviceAsWebcam must ignore the MI8 internal V4L2 nodes, and it must be awake
before the host probes the UVC gadget.

R13 physically validates every advertised 360p, 720p and 1080p mode at 15 and
30 FPS, including 18,000 intact 720p frames and five automated host USB resets.
It corrects the front-camera 180-degree landscape error and keeps the UVC
listener alive across cable reconnects. Automatic preview, no-lock startup,
UVC-only cable mode and secure ADB over Wi-Fi are also qualified. The exact
evidence is documented in
[`CURRENT_STATUS.md`](CURRENT_STATUS.md) and
[`lineageos/dipper/DEVELOPMENT_PLAN.md`](lineageos/dipper/DEVELOPMENT_PLAN.md).

Host-side enumeration can be checked with:

```bash
v4l2-ctl --list-devices
```

On OBS Studio 32.2.0 for Linux, select the direct capture node such as
`/dev/video0` for the CaCamOS source. OBS then recognizes the udev remove/add
events when the USB cable returns. R13 has one known limitation: capture can
subsequently freeze in OBS, and restarting OBS restores it.
