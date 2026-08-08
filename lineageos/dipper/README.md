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
- CaCamOS release: `1.1.1` dedicated webcam OS
- Previous release: `1.1.0`

The complete 1.1.0 USB qualification evidence is recorded in
[`V1_1_ACCEPTANCE.md`](V1_1_ACCEPTANCE.md). The physical display, touch-wake,
camera-idle and on-demand-audio qualification for version 1.1.1 is recorded in
[`V1_1_1_ACCEPTANCE.md`](V1_1_1_ACCEPTANCE.md).

## Important Difference From Mi 10 Pro

The MI10 Pro (`cmi`) kernel already exposes UVC. The MI8 (`dipper`) currently
does not.

Checked official sources show:

```text
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_UVC=<missing>
```

So the MI8 addon patches both the Android product and the kernel config
fragment. `CONFIG_USB_VIDEO_CLASS` is the unrelated USB host-camera driver; a
phone acting as a webcam requires the ConfigFS UVC gadget function instead.

## Integration

Prepare the LineageOS workspace from the CaCamOS repository root:

```bash
./tools/prepare-lineage-workspace.sh --init dipper /home/denis/Documents/Denis/dev/lineage-dipper
./tools/prepare-lineage-workspace.sh --local-manifest dipper /home/denis/Documents/Denis/dev/lineage-dipper
./tools/prepare-lineage-workspace.sh --sync dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

For a source-only webcam dependency sync before the full ROM sync:

```bash
./tools/prepare-lineage-workspace.sh --sync-webcam-deps dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Recommended path from this CaCamOS repository:

```bash
./lineageos/dipper/tools/install-into-lineage.sh /path/to/lineageos
```

Or apply the patch series manually from the root of a synced LineageOS tree:

```bash
for patch in /path/to/cacamos/lineageos/dipper/patches/*.patch; do
  git apply "$patch"
done
```

Verify the source tree before building:

```bash
/path/to/cacamos/lineageos/dipper/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineageos
/path/to/cacamos/lineageos/dipper/tools/verify-source-tree.sh /path/to/lineageos
```

Then build with the resource-controlled wrapper. It applies CPU affinity,
memory and swap preflight checks, a Go memory limit, and a runtime watchdog.
The current 8-core host configuration uses six build workers and reserves
two cores:

```bash
/path/to/cacamos/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --target bacon \
  --existing-graph \
  --jobs 6 \
  --cpu-set 0-5 \
  --reserve-cores 2 \
  --go-memlimit-mib 8192 \
  --min-free-mem-mib 3584 \
  --min-free-swap-mib 32768
```

On a machine with enough RAM, the normal LineageOS command remains:

```bash
source build/envsetup.sh
breakfast dipper
mka bacon
```

## Qualified OTA

CaCamOS 1.1.1 ships this exact signed MI8 OTA:

```text
lineage-22.2-20260803-UNOFFICIAL-CACAMOS-1.1.1-dipper.zip
size=1068468998
sha256=b7c4094cfacbd6c647d20e821764fd0421ce35f484f2d519632304a6be23c79a
build_incremental=1785784819
```

Download:
<https://github.com/LeMegaGeek/cacamos/releases/tag/v1.1.1>

After 30 seconds without interaction, the preview explicitly puts the display
to sleep and releases its local surface. Double-tap-to-wake remains enabled.
An open host UVC stream continues with the display off, and Android audio
capture/playback is created only while the matching host UAC2 endpoint is open.

## Runtime Validation

With the MI8 available through wireless ADB, run:

```bash
./tools/audit-connected-device.sh
./lineageos/dipper/tools/verify-webcam.sh
```

On an unpatched official Nightly, the expected result is a useful failure:
kernel UVC flags should be reported as missing. On CaCamOS, the verifier checks
the framework UVC default, the live USB HAL function, the kernel gadget, the
automatic preview, no-lock state and wireless ADB.

Host-side enumeration can be checked with:

```bash
v4l2-ctl --list-devices
```

The MI8 must appear as a USB/video capture device.

After installation, the strict automatic runtime gate checks the real UVC
function, lock state, wireless ADB, advertised modes, repeated raw JPEG
integrity and one sustained stream:

```bash
EXPECTED_BUILD_INCREMENTAL=1785784819 ADB_SERIAL=<wireless-ip:port> \
  ./lineageos/dipper/tools/qualify-runtime.sh
```

The shell may be unable to read `ro.usb.uvc.enabled` because of SELinux, so an
`unset` value alone does not identify the ROM. The authoritative runtime checks
are the framework overlay `config_usbDefaultToUvc=true` and USB HAL
`current_functions=0x80`.

To install the verified OTA from a local LineageOS workspace:

```bash
cd /home/denis/Documents/Denis/dev/cacamos/lineageos/dipper/tools
./flash-verified-build.sh \
  /home/denis/Documents/Denis/dev/lineage-dipper \
  /home/denis/Documents/Denis/dev/lineage-dipper/out/target/product/dipper/lineage_dipper-ota.zip
```

The supported MI8 installation path is deliberately singular:

1. Open Lineage Recovery on the phone.
2. Select **Apply update**, then **Apply from ADB**.
3. Run `flash-verified-build.sh` with the exact OTA path.

The installer first validates the source tree, compiled APK, kernel, staged
payload, device metadata and OTA signature. It then requires exactly one ADB
sideload device and refuses every other device state.

## Standard Host Applications

CaCamOS is a standard UVC device. Physical qualification passes stock OBS,
Chromium/WebRTC, GStreamer and VLC without BGOBS. The final OBS run captured
252 frames over 8.5 seconds at exactly 30 FPS.

The supported modes are MJPEG 1280x720, 1024x576 and 1920x1080 at 15 and
30 FPS. The warmup frame satisfies OBS's short initial-frame deadline,
and the periodic control-event drain preserves rapid close/reopen operation.

Do not use `svc usb resetUsbGadget` for diagnostics on the MI8. It can panic
this kernel. The qualification tool uses a host-side USB reset instead.

## Kernel-Only Test Boot

When a full LineageOS ROM build is not available yet, the CaCam OS UVC kernel
can be packaged into a test `boot.img` that reuses the official LineageOS
ramdisk:

```bash
./lineageos/dipper/tools/build-uvc-boot-image.sh \
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
