# CaCam OS

CaCam OS is the ROM-side track for exposing supported Android phones as real
USB webcams.

Unlike the Play Store CaCam app, this path targets the Android USB gadget stack:
the host computer should see a standard USB Video Class camera.

## Targets

Current source targets:

- Xiaomi Mi 10 Pro, codename `cmi`, LineageOS `23.2`
- Xiaomi Mi 8, codename `dipper`, LineageOS `22.2`

Use the LineageOS source addons for clean ROM builds:

```bash
./cacam-os/lineageos/cmi/tools/install-into-lineage.sh /path/to/lineageos
./cacam-os/lineageos/dipper/tools/install-into-lineage.sh /path/to/lineageos
```

Prepare or inspect a LineageOS workspace with:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

For a real build workspace, initialize it, write the local manifest, then sync:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --init dipper /home/denis/Documents/Denis/dev/lineage-dipper
./cacam-os/tools/prepare-lineage-workspace.sh --local-manifest dipper /home/denis/Documents/Denis/dev/lineage-dipper
./cacam-os/tools/prepare-lineage-workspace.sh --sync dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

The local manifest pins the matching LineageOS device tree, common tree, kernel
and TheMuppets vendor blobs for the selected device.

For preflight checks without the full ROM tree, use:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --sync-webcam-deps cmi /home/denis/Documents/Denis/dev/lineage-cmi
./cacam-os/lineageos/cmi/tools/check-lineage-source-preflight.sh /home/denis/Documents/Denis/dev/lineage-cmi
```

When a phone is connected, collect a non-destructive audit with:

```bash
./cacam-os/tools/audit-connected-device.sh
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
- `CONFIG_USB_VIDEO_CLASS`: missing in stock kernel config
- `CONFIG_USB_CONFIGFS_F_UVC`: missing in stock kernel config

So the `dipper` addon also patches the device-specific kernel config fragment.

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

The current `dipper` source addon includes those fixes plus the resource-limited
build wrapper. Completion now requires a full LineageOS ROM build, flashing it
on the MI8, then proving host-side UVC enumeration with:

```bash
v4l2-ctl --list-devices
```
