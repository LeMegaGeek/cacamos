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
- CaCamOS release: `1.2.1`

Qualified OTA:

```text
lineage-23.2-20260803-UNOFFICIAL-CACAMOS-1.2.1-cmi.zip
size=1422040935
sha256=7f82397716a3138699764ba072446977f45cdda893d9c4aa7419659268ccc003
build_incremental=1785781560
```

The physical energy, touch-wake, video and audio qualification is recorded in
[`V1_2_1_ACCEPTANCE.md`](V1_2_1_ACCEPTANCE.md).

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
- Recovery enables ADB for appliance maintenance and continues sideloading
  when the optional `/cache` partition cannot be mounted.
- The preview explicitly puts the display to sleep after 30 seconds; a double
  tap wakes it again.
- The local preview and unused Android audio paths become idle while host UVC
  or UAC2 streams are closed.

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

The current 8-core host profile uses six workers and leaves two cores free:

```bash
./lineageos/cmi/tools/build-lineage-gentle.sh \
  --lineage-root /path/to/lineage-cmi \
  --target bacon \
  --existing-graph \
  --jobs 6 \
  --cpu-set 0-5 \
  --reserve-cores 2 \
  --go-memlimit-mib 8192 \
  --min-free-mem-mib 3584 \
  --min-free-swap-mib 32768
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

Windows, Teams, OBS and browsers select CaCamOS through their normal camera and
audio device menus. Physical Linux qualification on the MI10 Pro passed for
display sleep and touch wake, video, microphone, speaker, reboot and rapid UVC
reopen. A physical Windows test on this MI10 Pro remains to be recorded.

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
