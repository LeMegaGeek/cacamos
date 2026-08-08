# CaCamOS 1.1.1 Acceptance Record

Status date: 2026-08-08

Status: energy and regression qualified on a physical Xiaomi Mi 8 and a Linux
host. The matching MI10 Pro qualification passed; public GitHub publication is
pending.

## Release Artifact

```text
release=lineage-22.2-20260803-UNOFFICIAL-CACAMOS-1.1.1-dipper.zip
source=out/target/product/dipper/lineage_dipper-ota.zip
size=1068468998
sha256=b7c4094cfacbd6c647d20e821764fd0421ce35f484f2d519632304a6be23c79a
build_incremental=1785784819
lineage=22.2-20260803-UNOFFICIAL-dipper
```

## Acceptance Matrix

| Requirement | Evidence | Status |
| --- | --- | --- |
| Exact-base source patches reproduce the audited worktrees | Fourteen-project `verify-patch-series.sh` run | Passed |
| OTA archive, payload, target identity and signature are valid | `verify-build-artifacts.sh` | Passed |
| The physical MI8 runs CaCamOS 1.1.1 build `1785784819` | Runtime properties over authenticated wireless ADB | Passed |
| The preview explicitly switches the display off after 30 seconds | Forty-second idle-energy run and `dumpsys power`/`dumpsys display` | Passed |
| Touch wake is enabled by Android and the power HAL | Secure setting plus `mDoubleTapWakeEnabled=true` | Passed |
| A physical double-tap wakes the dark display and restores the webcam UI | Supervised physical touch test | Passed |
| The local camera closes when the display and host UVC stream are idle | Empty CameraService active-client list after display sleep | Passed |
| The persistent webcam service remains alive with the display off | Physical runtime PID check | Passed |
| Idle USB audio holds no Android `AudioIn` wake lock | Power-service check with host endpoints closed | Passed |
| An active host UVC stream survives display sleep | 2,400/2,400 MJPEG frames at 1280x720/30 FPS | Passed |
| Video cadence and frame integrity remain stable | 1,800 frames over 60.102 seconds, 29.93 FPS | Passed |
| On-demand UAC2 audio still starts correctly | 288,000 microphone frames and physical speaker return | Passed |
| Video, microphone and speakers still operate together | 720p30 acoustic round trip, tone ratio 0.8018 | Passed |
| Standard Linux USB class drivers bind all functions | `uvcvideo`, `snd-usb-audio`, V4L2 and ALSA checks | Passed |
| Exact OTA and checksum are published publicly | GitHub release `v1.1.1` | Pending |

## Energy Behavior

With no host video or audio endpoint open, the preview put the display to sleep
after 30 seconds. CameraService then reported no active camera client, the
`AudioIn` partial wake lock was absent, and the persistent DeviceAsWebcam
service remained alive. A physical double-tap woke the display and returned
directly to the CaCamOS webcam interface.

With a host video endpoint open, display sleep did not interrupt the USB
stream. The host received all 2,400 requested MJPEG frames at 1280x720/30 FPS
while the display transitioned to the off state.

The USB audio bridge is now inactive until the host opens the corresponding
UAC2 endpoint. A regression run opened both directions on demand, played a
997 Hz signal through the telephone speakers and captured all 288,000 expected
mono microphone frames while 720p30 UVC video remained active.

## Scope

This record qualifies the 1.1.1 energy changes and preserves the broader Linux
and Windows UVC/UAC2 acceptance already recorded for version 1.1.0. The
companion MI10 Pro completed the same physical energy checks; public release
publication is the final gate.
