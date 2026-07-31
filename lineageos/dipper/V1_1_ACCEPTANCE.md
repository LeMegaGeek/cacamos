# CaCamOS 1.1.0 Acceptance Record

Status date: 2026-07-31

Status: release-qualified on a physical Xiaomi Mi 8, Linux host and Windows
host.

## Release Artifact

```text
release=lineage-22.2-20260729-UNOFFICIAL-CACAMOS-1.1.0-dipper.zip
source=out/target/product/dipper/lineage_dipper-ota.zip
size=1068470898
sha256=26c95ecf7ba4886b55f64bfae298b9f799c91fc8a2ee25476abc8f936f4879ca
build_incremental=1785352812
lineage=22.2-20260729-UNOFFICIAL-dipper
```

## Acceptance Matrix

| Requirement | Evidence | Status |
| --- | --- | --- |
| Reproducible source patches match the audited LineageOS worktrees | `verify-patch-series.sh --match-worktrees` | Passed |
| OTA integrity, payload gates and whole-package signature are valid | `verify-build-artifacts.sh` | Passed |
| Installed system identifies as CaCamOS 1.1.0 build `1785352812` | Physical MI8 properties | Passed |
| SELinux remains enforcing with the audio bridge active | Physical MI8 policy and runtime logs | Passed |
| One cable exposes a composite UVC and UAC2 device | Host enumeration of USB `18d1:4eef` | Passed |
| Linux uses standard video and audio class drivers | `uvcvideo`, `snd-usb-audio`, ALSA and PipeWire enumeration | Passed |
| The phone microphone is a mono 48 kHz, 16-bit standard input | ALSA capture and physical recording | Passed |
| The phone speakers are a stereo 48 kHz, 16-bit standard output | ALSA playback and physical listening test | Passed |
| Camera, microphone and speakers operate simultaneously | Acoustic round trip while UVC streamed at 720p30 | Passed |
| Every advertised UVC mode works while both audio directions are active | 720p, 1024x576 and 1080p at 15/30 FPS | Passed |
| Repeated host opens preserve video and bidirectional audio | Ten consecutive acoustic round trips | Passed |
| USB removal and re-enumeration recover all three functions | Five settled host USB reset cycles | Passed |
| Sustained simultaneous transport remains complete | 120 seconds, 3,600 video frames and 5,760,000 audio frames | Passed |
| PipeWire applications use the standard microphone and speaker nodes | `pw-record` and `pw-play` acoustic round trip | Passed |
| Windows uses CaCamOS as a standard camera, microphone and speaker | Physical Windows test, no CaCamOS host driver or application | Passed |
| Exact OTA and checksum are published publicly | GitHub release `v1.1.0` | Passed |

## Physical Linux Evidence

The final OTA enumerated as `Google Inc. CaCamOS Webcam` at USB ID
`18d1:4eef`. ALSA exposed one mono capture PCM and one stereo playback PCM on
the `CaCamOS Webcam` card. PipeWire exposed corresponding standard source and
sink nodes.

The acoustic round-trip test played a 997 Hz signal from the host through the
phone speakers and recorded it through the phone microphone while UVC was
streaming. The final enforced run delivered all 480,000 expected microphone
frames with a 0.7413 tone ratio. A PipeWire run at full endpoint volume reached
a 0.8436 tone ratio.

All six UVC combinations passed with audio active:

```text
1280x720 at 15 and 30 FPS
1024x576 at 15 and 30 FPS
1920x1080 at 15 and 30 FPS
```

The two-minute 720p30 run delivered exactly 5,760,000 microphone frames and
3,600 video frames. Its tone window had 299.38 RMS and a 0.9730 tone ratio;
the video stream ended at approximately 29.88 FPS.

Evidence is retained under these local qualification directories:

```text
dist/cacam-os-qualifications/1.1.0-linux-audio-enforcing-ota
dist/cacam-os-qualifications/1.1.0-linux-av-*
dist/cacam-os-qualifications/1.1.0-linux-audio-reopen-*
dist/cacam-os-qualifications/1.1.0-linux-usb-reset-settled-*
dist/cacam-os-qualifications/1.1.0-linux-pipewire-full-volume
```

## Physical Windows Evidence

On 2026-07-31, the final installed OTA was physically tested on Windows. The
same USB cable provided a working standard webcam, microphone input and audio
output through the phone speakers. No BGOBS plugin, CaCamOS host program or
custom Windows driver was used.

`tools/verify-windows-usb-av.ps1` is included to inspect the Windows PnP
bindings for the composite device, `usbvideo`, `usbaudio2`, microphone endpoint
and speaker endpoint.

## Scope

CaCamOS 1.1.0 is qualified for the Xiaomi Mi 8 (`dipper`) on Linux and
Windows. macOS is outside the release scope.
