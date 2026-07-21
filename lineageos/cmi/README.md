# CaCam OS for Xiaomi Mi 10 Pro (`cmi`)

This directory contains the LineageOS-side integration for turning a Xiaomi Mi
10 Pro into a real USB webcam through Android's `DeviceAsWebcam` service.

It is not a Play Store app variant. It is a ROM/addon integration: the phone
advertises the standard USB Video Class gadget function, so Linux, Windows,
macOS, OBS and browser video inputs see the phone as a normal webcam.

## Target

- Device: Xiaomi Mi 10 Pro
- Codename: `cmi`
- Platform: Qualcomm `sm8250` / `kona`
- LineageOS branch checked: `lineage-23.2`
- Kernel requirement: already satisfied on LineageOS `android_kernel_xiaomi_sm8250`

The checked kernel config already exposes the required options:

```text
CONFIG_MEDIA_USB_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

## Integration

Prepare the LineageOS workspace from the CaCamOS repository root:

```bash
./tools/prepare-lineage-workspace.sh --init cmi /home/denis/Documents/Denis/dev/lineage-cmi
./tools/prepare-lineage-workspace.sh --local-manifest cmi /home/denis/Documents/Denis/dev/lineage-cmi
./tools/prepare-lineage-workspace.sh --sync cmi /home/denis/Documents/Denis/dev/lineage-cmi
```

For a source-only preflight before the full ROM sync:

```bash
./tools/prepare-lineage-workspace.sh --sync-webcam-deps cmi /home/denis/Documents/Denis/dev/lineage-cmi
./lineageos/cmi/tools/check-lineage-source-preflight.sh /home/denis/Documents/Denis/dev/lineage-cmi
```

If a deliberately partial sync was interrupted, `--allow-partial` reports
missing large projects as warnings. Do not use that mode as final build proof.

Recommended path from this CaCamOS repository:

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineageos
```

Or apply the patch manually from the root of a synced LineageOS tree:

```bash
git apply /path/to/cacamos/lineageos/cmi/patches/0001-cmi-enable-cacam-os-webcam.patch
```

Verify the source tree before building:

```bash
/path/to/cacamos/lineageos/cmi/tools/verify-source-tree.sh /path/to/lineageos
```

Then build normally:

```bash
source build/envsetup.sh
breakfast cmi
mka bacon
```

Host prerequisites and the current machine audit are tracked in
`BUILD_REQUIREMENTS.md`. Run this from a candidate LineageOS root:

```bash
/path/to/cacamos/lineageos/cmi/tools/check-build-host.sh
```

The patch does three things:

- Adds the privileged `DeviceAsWebcam` package to the `cmi` product.
- Enables UVC advertisement through `ro.usb.uvc.enabled=true`.
- Adds a `CaCamOsDeviceAsWebcamCmi` overlay placeholder for future camera
  physical-ID tuning.

The installer refuses to continue if the target tree does not contain the
LineageOS `cmi` device tree, `packages/services/DeviceAsWebcam`, or the QTI USB
gadget HAL. The verifier also checks that the QTI USB gadget HAL handles
`GadgetFunction::UVC`, links `uvc.0`, and that `hal_usb_gadget_server` can read
`ro.usb.uvc.enabled`.

The preflight checker is non-destructive: it runs `git apply --check` against
the synced source tree and validates the existing HAL, SELinux and kernel UVC
pieces before the CaCam OS patch is applied.

It also detects an already-patched tree and validates the installed CaCam OS
overlay instead of failing on a patch that is no longer applicable.

The current local source status is recorded in `CURRENT_SOURCE_PREFLIGHT.md`.

## Current Device Audit

The attached Mi 10 Pro running `23.2-20260626-NIGHTLY-cmi` was checked on
2026-07-01. It already has:

- `CONFIG_MEDIA_USB_SUPPORT=y`
- `CONFIG_USB_VIDEO_CLASS=y`
- `CONFIG_USB_CONFIGFS_F_UVC=y`
- `package:com.android.DeviceAsWebcam`
- QTI USB gadget services running under `vendor_hal_usb_qti`
- compiled SELinux policy mapping `vendor_hal_usb_qti` into
  `hal_usb_gadget_server`

But it does not expose webcam mode yet because:

```text
ro.usb.uvc.enabled=<unset>
```

So the ROM addon intentionally enables `ro.usb.uvc.enabled=true` at build time
in the `cmi` product, while keeping `DeviceAsWebcam` explicitly included and
verifying the HAL path before build.

## Runtime Check

After flashing the build, boot the phone, plug it into a computer and run:

```bash
./lineageos/cmi/tools/verify-webcam.sh
```

Expected Android-side signals:

- `ro.product.device` is `cmi`.
- `ro.usb.uvc.enabled` is `true`.
- USB state/functions can include `uvc` when webcam mode is selected.

Expected host-side signals:

- Linux: `v4l2-ctl --list-devices` shows the phone as a video capture device.
- OBS: a regular Video Capture Device entry appears, no BGOBS plugin required.
- Windows/macOS: the device appears as a normal USB camera if the USB gadget is
  accepted by the host.

## Optional Root Runtime Variant

If rebuilding LineageOS is not practical and the phone is rooted with Magisk,
use the separate module:

```text
dist/CaCamOS-cmi-webcam-magisk-0.2.3.zip
```

It sets `ro.usb.uvc.enabled=true` at boot with Magisk `resetprop`. It does not
force `sys.usb.config=uvc`; Android and `DeviceAsWebcam` still select the actual
USB webcam function.

On the attached Mi 10 Pro, temporary Magisk boot works with a matching patched
`20260626` boot image. Root is exposed as `/debug_ramdisk/su` during that
temporary boot. A runtime `resetprop` test is useful for diagnostics, but the
clean target remains a LineageOS build where `ro.usb.uvc.enabled=true` exists
from boot.

## Camera Mapping

The initial overlay keeps the AOSP defaults:

```json
{}
```

That means `DeviceAsWebcam` will rely on the logical camera list exposed by the
Camera HAL. Once a real `cmi` build is flashed, run:

```bash
adb shell dumpsys media.camera > cmi-camera-dump.txt
```

Then update `physical_camera_mapping.json` if we want explicit labels such as
wide, ultra-wide or telephoto in the webcam picker.

## References

- Android Device-as-Webcam architecture:
  https://source.android.com/docs/core/camera/webcam
- LineageOS DeviceAsWebcam package:
  https://github.com/LineageOS/android_packages_services_DeviceAsWebcam
- LineageOS `sm8250` kernel UVC config:
  https://github.com/LineageOS/android_kernel_xiaomi_sm8250/blob/lineage-23.2/arch/arm64/configs/vendor/kona-perf_defconfig
