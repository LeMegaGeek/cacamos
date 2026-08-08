# CaCamOS 1.2.1 Acceptance Record

Status date: 2026-08-08

Status: energy and regression qualified on a physical Xiaomi Mi 10 Pro and a
Linux host. Public GitHub publication is pending.

## Release Artifact

```text
release=lineage-23.2-20260803-UNOFFICIAL-CACAMOS-1.2.1-cmi.zip
source=out/target/product/cmi/lineage_cmi-ota.zip
size=1422040935
sha256=7f82397716a3138699764ba072446977f45cdda893d9c4aa7419659268ccc003
build_incremental=1785781560
lineage=23.2-20260803-UNOFFICIAL-cmi
```

## Acceptance Matrix

| Requirement | Evidence | Status |
| --- | --- | --- |
| Exact-base source patches reproduce the audited worktrees | Fourteen-project `verify-patch-series.sh` run | Passed |
| OTA archive, target identity, signature and embedded recovery are valid | `verify-build-artifacts.sh` | Passed |
| The physical MI10 Pro runs CaCamOS 1.2.1 build `1785781560` | Runtime properties over authenticated wireless ADB | Passed |
| The appliance is clean and localized in French | Zero third-party packages and device locale `fr-FR` | Passed |
| The preview explicitly switches the display off after 30 seconds | Idle-energy run and `dumpsys power`/`dumpsys display` | Passed |
| Touch wake is enabled by Android and the power HAL | Secure setting plus `mDoubleTapWakeEnabled=true` | Passed |
| A physical double-tap wakes the dark display and restores the webcam UI | Supervised physical touch test and resumed-activity check | Passed |
| The local camera closes when display and host UVC are idle | Empty CameraService active-client list after display sleep | Passed |
| The persistent webcam service remains alive with the display off | Physical runtime PID check | Passed |
| Idle USB audio holds no Android `AudioIn` wake lock | Power-service check with host endpoints closed | Passed |
| An active host UVC stream survives display sleep | 2,400/2,400 MJPEG frames at 1280x720/30 FPS | Passed |
| Video cadence and frame integrity remain stable | 1,800 intact frames over 60.198 seconds, 29.88 FPS | Passed |
| The 1080p mode remains usable | 450 intact frames at 1920x1080/30 FPS | Passed |
| Host applications can repeatedly close and reopen UVC | 20/20 rapid STREAMON cycles | Passed |
| On-demand UAC2 audio still starts correctly | 288,000 microphone frames and physical speaker return | Passed |
| Video, microphone and speakers operate together | 720p30 acoustic round trip, tone ratio 0.1751 | Passed |
| Standard Linux USB class drivers bind all functions | `uvcvideo`, `snd-usb-audio`, V4L2 and ALSA checks | Passed |
| Damaged optional `/cache` no longer blocks installation | Physical 1.2.1 ADB sideload completed at `Total xfer: 1.00x` | Passed |
| Exact OTA and checksum are published publicly | GitHub release `v1.2.1` | Pending |

## Energy Behavior

With no host video or audio endpoint open, the preview put the display to sleep
after 30 seconds. CameraService then reported no active camera client, the
`AudioIn` partial wake lock was absent, and the persistent DeviceAsWebcam
service remained alive. A physical double-tap woke the display, and Android
reported the CaCamOS preview as the resumed activity.

Display sleep did not interrupt an active host video stream. The host received
all 2,400 requested MJPEG frames at 1280x720/30 FPS while the display remained
off. A separate 60-second run decoded all 1,800 frames and measured 29.88 FPS.

The USB audio bridge stayed idle until the host opened its UAC2 endpoints. A
regression run played a 997 Hz signal through the telephone speakers and
captured all 288,000 expected microphone frames while 720p30 UVC video was
active.

## Evidence

The retained local host evidence is under:

```text
dist/cacam-os-qualifications/20260808-172055-cmi-usb-audio
dist/cacam-os-qualifications/20260808-172142-cmi-reopen
dist/cacam-os-qualifications/20260808-173450-cmi-screenoff-uvc
dist/cacam-os-qualifications/20260808-173830-cmi-runtime
```

The physical touch action was supervised live. Immediately after the gesture,
PowerManager reported `mWakefulness=Awake`, DisplayManager reported
`mScreenState=ON`, and DeviceAsWebcamPreview was the top resumed activity.

## Scope

This record qualifies the 1.2.1 energy changes and the recovery resilience
needed to install the release on the physical MI10 Pro. It preserves the
broader UVC/UAC2 behavior qualified in 1.2.0. Public release publication remains
the final gate.
