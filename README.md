# CaCamOS

CaCamOS turns a supported Android phone into a standard USB webcam,
microphone and speaker. The host uses its normal USB Video Class and USB
Audio Class 2 drivers, so no CaCam application, BGOBS plugin or network
transport is required.

## Xiaomi Mi 10 Pro Release

CaCamOS 1.2.1 is the current dedicated-OS release for the Xiaomi Mi 10 Pro
(`cmi`), based on LineageOS 23.2 / Android 16. It carries the same standard UVC
webcam and bidirectional UAC2 audio design as the MI8 release, adapted to the
Snapdragon 865 kernel and the newer Android source tree.

The MI10 Pro port includes:

- CaCamOS boot branding and automatic persistent webcam preview;
- no lock screen, consumer setup, generic launcher, browser, gallery or music
  application;
- MJPEG 1280x720, 1024x576 and 1920x1080 at 15 and 30 FPS;
- standard USB microphone and speakers at 48 kHz;
- authenticated wireless ADB while the physical cable stays dedicated to UVC
  and UAC2;
- recovery maintenance that remains usable when the optional `/cache`
  partition is unavailable;
- a reproducible fourteen-patch series and controlled six-worker build profile.

**Clean-install requirement:** the first installation from LineageOS or a
CaCamOS 0.x build must include **Format data / factory reset** in Lineage
Recovery. Sideloading an OTA updates the OS but does not erase `/data`; skipping
this step preserves old applications, accounts, credentials and notifications.

The 1.2.1 OTA is built from the reproducible source series and passes the
archive, payload, target-identity and whole-package-signature gates:

```text
lineage-23.2-20260803-UNOFFICIAL-CACAMOS-1.2.1-cmi.zip
size=1422040935
sha256=7f82397716a3138699764ba072446977f45cdda893d9c4aa7419659268ccc003
build_incremental=1785781560
```

Download:
<https://github.com/LeMegaGeek/cacamos/releases/tag/v1.2.1>

## Xiaomi Mi 8 Release

CaCamOS 1.1.1 is the current dedicated webcam OS for the Xiaomi Mi 8
(`dipper`), based on LineageOS 22.2:

```text
lineage-22.2-20260803-UNOFFICIAL-CACAMOS-1.1.1-dipper.zip
size=1068468998
sha256=b7c4094cfacbd6c647d20e821764fd0421ce35f484f2d519632304a6be23c79a
build_incremental=1785784819
```

Download:
<https://github.com/LeMegaGeek/cacamos/releases/tag/v1.1.1>

The OS is deliberately narrow:

- boots with CaCamOS branding directly into the webcam preview;
- has no lock screen or consumer setup flow;
- removes the browser, gallery, music player and generic launcher;
- exposes UVC video and bidirectional UAC2 audio on the physical USB cable;
- keeps authenticated ADB maintenance available over Wi-Fi;
- works as a normal camera, microphone and speaker in Linux and Windows
  applications.

The advertised MJPEG modes are:

| Resolution | Frame rates |
| --- | --- |
| 1280x720 | 15, 30 FPS |
| 1024x576 | 15, 30 FPS |
| 1920x1080 | 15, 30 FPS |

The 1.1.x image keeps the standard-UVC and stability fixes qualified in 1.0.0
and adds standard USB audio. The MI8 microphone appears as a mono 48 kHz,
16-bit input. Its speakers appear as a stereo 48 kHz, 16-bit output. Video and
both audio directions work simultaneously through one cable.

Version 1.1.1 on the MI8 and version 1.2.1 on the MI10 Pro add an idle-energy
policy. The preview explicitly puts the display to sleep after 30 seconds
without interaction and a double tap wakes it again. The local preview is
released while the display is off; an open host UVC stream continues normally,
while an unused camera can become idle. Android microphone capture and speaker
playback now start only while the host has opened the corresponding UAC2
endpoint.

The MI8 energy and regression qualification is recorded in
[`lineageos/dipper/V1_1_1_ACCEPTANCE.md`](lineageos/dipper/V1_1_1_ACCEPTANCE.md).
The matching MI10 Pro qualification is recorded in
[`lineageos/cmi/V1_2_1_ACCEPTANCE.md`](lineageos/cmi/V1_2_1_ACCEPTANCE.md).

Physical qualification on the MI8 includes:

- every advertised mode at its requested cadence;
- 100 rapid UVC close/reopen cycles;
- stock OBS capture at 30 FPS without BGOBS;
- Chromium WebRTC, GStreamer and VLC;
- 3,600 intact 720p frames over two minutes at 29.94 FPS;
- five host USB resets followed by successful capture;
- correct orientation and colors in portrait and landscape;
- simultaneous video, microphone capture and speaker playback on Linux;
- ten repeated audio/video opens and five USB resets with audio recovery;
- standard camera, microphone and speaker operation on Windows without a
  CaCamOS driver or host application.

The complete acceptance record is in
[`lineageos/dipper/V1_1_ACCEPTANCE.md`](lineageos/dipper/V1_1_ACCEPTANCE.md).

## Installation

CaCamOS installation is supported only through Lineage Recovery and ADB
sideload:

1. Boot the phone into Lineage Recovery.
2. For the first move from LineageOS or CaCamOS 0.x, select **Factory reset**,
   then **Format data / factory reset**. This mandatory step erases `/data` and
   removes all legacy applications, accounts, credentials and notifications.
   ADB sideload alone does not perform this erasure.
3. Select **Apply update**, then **Apply from ADB**.
4. On the host, run the command for the target device.

MI10 Pro:

```bash
adb sideload lineage-23.2-20260803-UNOFFICIAL-CACAMOS-1.2.1-cmi.zip
```

MI8:

```bash
adb sideload lineage-22.2-20260803-UNOFFICIAL-CACAMOS-1.1.1-dipper.zip
```

After startup, connect the phone to Wi-Fi once for authenticated wireless ADB
maintenance. The USB cable remains dedicated to UVC and UAC2.

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

For the MI10 Pro LineageOS 23.2 tree, use the device-specific series:

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineage-cmi
./lineageos/cmi/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineage-cmi
./lineageos/cmi/tools/verify-source-tree.sh /path/to/lineage-cmi
```

On the current 8-core build host, the resource-controlled build uses six
cores and reserves two:

```bash
./lineageos/dipper/tools/build-lineage-gentle.sh \
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

The MI8 and MI10 Pro both have downloadable OTA releases. Version 1.2.0 also
introduced the complete MI10 Pro source integration; versions 1.1.1 and 1.2.1
add the shared idle-energy policy and its verification tooling.

## Host Check

On Linux, confirm enumeration with:

```bash
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
arecord -l
aplay -l
```

In OBS, Teams, a browser or another application, select `CaCamOS Webcam` as
the camera, microphone or audio output. Windows and Linux use their built-in
USB class drivers.
