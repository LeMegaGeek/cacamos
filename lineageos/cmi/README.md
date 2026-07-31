# CaCamOS for Xiaomi Mi 10 Pro (`cmi`)

This directory contains the complete LineageOS-side integration for turning a
Xiaomi Mi 10 Pro into a dedicated standard USB webcam, microphone and speaker.
The host uses its built-in UVC and UAC2 drivers; BGOBS and network streaming are
not involved.

## Target

- Device: Xiaomi Mi 10 Pro
- Codename: `cmi`
- Platform: Qualcomm Snapdragon 865 / `sm8250`
- Base: LineageOS 23.2 / Android 16
- CaCamOS source release: `1.2.0`

The kernel already enables the required gadget functions:

```text
CONFIG_USB_CONFIGFS_F_UVC=y
CONFIG_USB_CONFIGFS_F_UAC2=y
```

CaCamOS extends that baseline with the robust UVC request pipeline, standard
USB audio descriptors and Android appliance behavior qualified on the MI8.

## Appliance Behavior

- CaCamOS boot branding and automatic webcam preview.
- No lock screen, setup wizard, generic launcher, browser, gallery or music app.
- UVC video and UAC2 audio own the physical USB cable.
- Authenticated ADB maintenance remains available over Wi-Fi.
- Settings contains a direct return-to-webcam action.
- Recovery enables ADB for appliance maintenance.

The advertised video modes are MJPEG 1280x720, 1024x576 and 1920x1080 at 15
and 30 FPS. The regular front-camera Camera2 path tops out at 30 FPS; the
camera's constrained high-speed modes are deliberately not advertised as
ordinary UVC modes without a dedicated high-speed capture-session path.

## Source Integration

Prepare a full LineageOS workspace:

```bash
./tools/prepare-lineage-workspace.sh --init cmi /path/to/lineage-cmi
./tools/prepare-lineage-workspace.sh --local-manifest cmi /path/to/lineage-cmi
./tools/prepare-lineage-workspace.sh --sync cmi /path/to/lineage-cmi
```

Apply the complete patch series:

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineage-cmi
```

The fourteen patches are tied to exact audited LineageOS revisions. Verify that
they reproduce the current worktrees and that all appliance invariants hold:

```bash
./lineageos/cmi/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineage-cmi
./lineageos/cmi/tools/verify-source-tree.sh /path/to/lineage-cmi
```

## Controlled Build

The qualified 16-core host profile uses ten workers and leaves six cores free:

```bash
./lineageos/cmi/tools/build-lineage-gentle.sh \
  --lineage-root /path/to/lineage-cmi \
  --target bacon \
  --jobs 10 \
  --cpu-set 0-9 \
  --reserve-cores 6 \
  --go-memlimit-mib 18432 \
  --min-free-mem-mib 2048 \
  --min-free-swap-mib 16384
```

The wrapper performs memory and swap preflight checks, caps CPU affinity and
build parallelism, lowers scheduler priority and stops the build if available
memory falls below the configured threshold. It also verifies that the arm64
Chromium WebView Git LFS object is present before starting Soong.

## Runtime Check

After installation, connect through authenticated wireless ADB and run:

```bash
./lineageos/cmi/tools/verify-webcam.sh
```

On Linux, the host should expose the standard devices through `uvcvideo` and
UAC2:

```bash
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
arecord -l
aplay -l
```

Windows, Teams, OBS and browsers should select CaCamOS through their normal
camera and audio device menus. Physical MI10 Pro qualification remains pending.

## Reproducibility

The source publication contains changes for:

- `device/xiaomi/cmi`
- `frameworks/base`
- `packages/services/DeviceAsWebcam`
- `kernel/xiaomi/sm8250`
- `system/sepolicy`
- `vendor/qcom/opensource/usb`
- `packages/apps/Settings`
- `packages/modules/adb`
- `vendor/lineage`
- `build/make`, `build/soong` and `build/blueprint`
- `bootable/recovery`
- `system/core`

The exact base commits are encoded in `tools/verify-patch-series.sh`.
