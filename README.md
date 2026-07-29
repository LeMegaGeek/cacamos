# CaCamOS

CaCamOS turns a supported Android phone into a standard USB Video Class
webcam. The host uses the normal UVC driver, so no CaCam application, BGOBS
plugin or network video transport is required.

## Xiaomi Mi 8 Release

CaCamOS 1.0.0 is the first dedicated webcam OS for the Xiaomi Mi 8
(`dipper`), based on LineageOS 22.2:

```text
lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
size=1068308344
sha256=7ff904f2bd95bda315266ab7c40b5d1fa2c2a6a354c53c15ae0393761360e1ea
build_incremental=1785337449
```

Download:
<https://github.com/LeMegaGeek/cacamos/releases/tag/v1.0.0>

The OS is deliberately narrow:

- boots with CaCamOS branding directly into the webcam preview;
- has no lock screen or consumer setup flow;
- removes the browser, gallery, music player and generic launcher;
- exposes only UVC on the physical USB cable;
- keeps authenticated ADB maintenance available over Wi-Fi;
- works as a normal webcam in OBS, Chromium/WebRTC, GStreamer and VLC.

The advertised MJPEG modes are:

| Resolution | Frame rates |
| --- | --- |
| 1280x720 | 15, 30 FPS |
| 1024x576 | 15, 30 FPS |
| 1920x1080 | 15, 30 FPS |

The 1.0.0 image fixes the former stock-OBS startup timeout by queuing a valid
MJPEG warmup frame before UVC streaming starts. It also keeps processing UVC
control events across rapid stream close/reopen cycles and treats a removed
USB endpoint as a normal disconnect.

Physical qualification on the MI8 includes:

- every advertised mode at its requested cadence;
- 100 rapid UVC close/reopen cycles;
- stock OBS capture at 30 FPS without BGOBS;
- Chromium WebRTC, GStreamer and VLC;
- 3,600 intact 720p frames over two minutes at 29.94 FPS;
- five host USB resets followed by successful capture;
- correct orientation and colors in portrait and landscape.

The complete acceptance record is in
[`lineageos/dipper/V1_ACCEPTANCE.md`](lineageos/dipper/V1_ACCEPTANCE.md).

## Installation

CaCamOS MI8 installation is supported only through Lineage Recovery and ADB
sideload:

1. Boot the phone into Lineage Recovery.
2. For the first move from LineageOS or CaCamOS 0.x, format data. This erases
   the phone and removes legacy credentials and user state.
3. Select **Apply update**, then **Apply from ADB**.
4. On the host, run:

```bash
adb sideload lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.0.0-dipper.zip
```

After startup, connect the phone to Wi-Fi once for authenticated wireless ADB
maintenance. The USB cable remains dedicated to UVC.

Do not use Android's `svc usb resetUsbGadget` command on this MI8 kernel. Use
an ordinary cable reconnect or a host-side USB reset.

## Source Integration

Clone the repository:

```bash
git clone https://github.com/LeMegaGeek/cacamos.git
cd cacamos
```

Install the MI8 patch series into a synced LineageOS 22.2 tree:

```bash
./lineageos/dipper/tools/install-into-lineage.sh /path/to/lineageos
```

Verify the resulting source tree:

```bash
./lineageos/dipper/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineageos
./lineageos/dipper/tools/verify-source-tree.sh /path/to/lineageos
```

On the current 16-core build host, the qualified resource-controlled build
uses ten cores and reserves six:

```bash
./lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --target bacon \
  --existing-graph \
  --jobs 10 \
  --cpu-set 0-9 \
  --reserve-cores 6 \
  --go-memlimit-mib 8192 \
  --min-free-mem-mib 5120 \
  --min-free-swap-mib 32768
```

The repository also retains the Mi 10 Pro (`cmi`) source addon. CaCamOS 1.0.0
is qualified and released only for the Xiaomi Mi 8.

## Host Check

On Linux, confirm enumeration with:

```bash
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

In OBS, Teams, a browser or another video application, select the standard
`UVC Camera` device.
