# CaCam OS for Xiaomi Mi 8 (`dipper`)

This directory contains the LineageOS-side integration for turning a Xiaomi Mi 8
into a real USB webcam through Android's `DeviceAsWebcam` service.

The host computer should see a standard USB Video Class camera. OBS, browsers
and desktop applications should use it as a normal webcam, without BGOBS and
without network streaming.

## Target

- Device: Xiaomi Mi 8
- Codename: `dipper`
- Platform: Qualcomm `sdm845`
- LineageOS branch checked: `lineage-22.2`
- Latest official build checked: `lineage-22.2-20260627-nightly-dipper-signed.zip`

## Important Difference From Mi 10 Pro

The MI10 Pro (`cmi`) kernel already exposes UVC. The MI8 (`dipper`) currently
does not.

Checked official sources show:

```text
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_VIDEO_CLASS=<missing>
CONFIG_USB_CONFIGFS_F_UVC=<missing>
```

So the MI8 addon patches both the Android product and the kernel config
fragment.

## Integration

Prepare the LineageOS workspace from the CaCam repository:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --init dipper /home/denis/Documents/Denis/dev/lineage-dipper
./cacam-os/tools/prepare-lineage-workspace.sh --local-manifest dipper /home/denis/Documents/Denis/dev/lineage-dipper
./cacam-os/tools/prepare-lineage-workspace.sh --sync dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

For a source-only webcam dependency sync before the full ROM sync:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --sync-webcam-deps dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Recommended path from this CaCam repository:

```bash
./cacam-os/lineageos/dipper/tools/install-into-lineage.sh /path/to/lineageos
```

Or apply the patch manually from the root of a synced LineageOS tree:

```bash
git apply /path/to/CaCam/cacam-os/lineageos/dipper/patches/0001-dipper-enable-cacam-os-webcam.patch
```

Verify the source tree before building:

```bash
/path/to/CaCam/cacam-os/lineageos/dipper/tools/verify-source-tree.sh /path/to/lineageos
```

Then build. On Denis' current desktop, use the conservative wrapper first. It
checks memory, forces a single low-priority build job, reserves two CPU cores
for the desktop when `taskset` is available, and stops the build if available
memory drops too low while it is running:

```bash
/path/to/CaCam/cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --check-only

/path/to/CaCam/cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper
```

The default CPU reservation can be adjusted if needed:

```bash
/path/to/CaCam/cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --reserve-cores 3
```

The runtime memory watchdog defaults to stopping the build below 3072 MiB of
`MemAvailable`. To use a stricter threshold:

```bash
/path/to/CaCam/cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --min-free-mem-mib 4096
```

On a machine with enough RAM, the normal LineageOS command remains:

```bash
source build/envsetup.sh
breakfast dipper
mka bacon
```

## Runtime Test Tonight

With the MI8 connected by ADB, run:

```bash
./cacam-os/tools/audit-connected-device.sh
./cacam-os/lineageos/dipper/tools/verify-webcam.sh
```

On an unpatched official Nightly, the expected result is a useful failure:
kernel UVC flags should be reported as missing. After flashing a CaCam OS build,
the same script should show `ro.usb.uvc.enabled=true` and kernel UVC enabled.

Final success still requires host-side enumeration:

```bash
v4l2-ctl --list-devices
```

The MI8 must appear as a USB/video capture device.

## Kernel-Only Test Boot

When a full LineageOS ROM build is not available yet, the CaCam OS UVC kernel
can be packaged into a test `boot.img` that reuses the official LineageOS
ramdisk:

```bash
./cacam-os/lineageos/dipper/tools/build-uvc-boot-image.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --kernel-image /home/denis/Documents/Denis/dev/lineage-dipper/out-kernel-cacam-dipper/arch/arm64/boot/Image.gz-dtb \
  --date 2026-06-27 \
  --out dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
```

Current generated test boot:

```text
dist/magisk-test/CaCamOS-dipper-uvc-boot-20260627.img
sha256=a21bb8924c910e9f180d7a033271e38a8219063e1a0ed71c7010d627de19c1e9
```

This proves the kernel side only. The official ramdisk still leaves
`ro.usb.uvc.enabled` unset, so the Magisk test module or a full CaCam OS ROM
build is still required for the USB gadget HAL to allow webcam mode.

## References

- Android Device-as-Webcam architecture:
  https://source.android.com/docs/core/camera/webcam
- LineageOS `dipper` builds:
  https://download.lineageos.org/devices/dipper/builds
- LineageOS `dipper` device tree:
  https://github.com/LineageOS/android_device_xiaomi_dipper
- LineageOS `sdm845` kernel:
  https://github.com/LineageOS/android_kernel_xiaomi_sdm845
