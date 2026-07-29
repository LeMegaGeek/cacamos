# CaCamOS MI8 Development Plan

Plan date: 2026-07-27

## Acceptance Target

The result is a reproducible LineageOS 22.2 OTA for Xiaomi Mi 8 (`dipper`) that
boots into the webcam interface, uses UVC alone on the cable, keeps ADB over
Wi-Fi, and streams stable, correctly oriented video in OBS.

## Phase 1: Evidence and Root Causes

Status: complete.

- Preserve raw MJPEG and host/kernel logs rather than diagnose only from OBS.
- Fix malformed frames and the deterministic short-frame freeze.
- Enforce the negotiated 15/30 FPS cadence.
- Audit camera callbacks, buffer ownership, color conversion, rotation, USB
  policy, direct boot and ADB-over-Wi-Fi persistence.
- Identify the R12 cable-reconnect lifecycle from simultaneous phone and host
  evidence.
- Identify the front-camera landscape transform from physical MI8 output.

## Phase 2: Automatic Gates

Status: complete.

- `verify-source-tree.sh` checks policy, lifecycle and critical source logic.
- `verify-patch-series.sh` checks exact upstream bases and live-worktree parity.
- `verify-build-artifacts.sh` checks freshness, staged payloads, signatures,
  permissions, metadata and OTA contents.
- `build-lineage-gentle.sh` reserves cores, limits parallelism, lowers CPU and
  I/O priority, enforces a memory floor and can reuse a valid Ninja graph.
- `flash-verified-build.sh` permits only a verified recovery sideload.
- `test-host-uvc-stream.sh` checks every raw JPEG, decodes every frame and
  measures the delivered cadence.

## Phase 3: R12 Data-Path Qualification

Status: complete.

- USB enumerated as `18d1:4eed` with capture and metadata nodes.
- Every advertised MJPEG and YUYV mode passed at both 15 and 30 FPS.
- Measured rates stayed within the strict 0.90 to 1.10 negotiated ratio.
- Every raw MJPEG frame passed boundary and decoder checks.
- MJPEG 1280x720 at 30 FPS delivered 18,000 frames over 600.653 seconds without
  freezing.
- Portrait output, colors and fixed 16:9 bars were usable in OBS.

The qualification exposed two remaining failures: the front camera was rotated
180 degrees in landscape, and a physical cable reconnect stopped the userspace
UVC listener while leaving the Java service bound.

## Phase 4: R13 Device Qualification

Status: complete.

1. Built the exact R13 OTA with controlled resources.
2. Verified source parity, compiled payloads, archive integrity and the
   whole-package signature.
3. Installed through Lineage Recovery and ADB sideload.
4. Confirmed incremental `1785181771` and clean completed boots.
5. Confirmed no lock screen, automatic UVC selection and automatic preview.
6. Confirmed automatic secure ADB over Wi-Fi without cable ADB.
7. Confirmed upright front-camera portrait and landscape output, working camera
   switching, upright phone controls, correct colors and stable portrait bars.
8. Passed every advertised MJPEG and YUYV mode at 15 and 30 FPS.
9. Delivered 18,000 intact 720p MJPEG frames over ten minutes.
10. Passed two physical cable cycles and five host USB reset cycles without a
    phone reboot or webcam-process restart.
11. Confirmed OBS detects three USB remove/add cycles with the direct
    `/dev/video0` path; a later capture timeout remains a documented R13
    limitation and requires restarting OBS.
12. Rebooted and reconfirmed automatic UVC, preview, no-lock and wireless ADB.

Failures retain their logs and raw captures before any source decision. A new
build is required only when ROM source changes.

The automated stream regression uses:

```bash
EXPECTED_BUILD_INCREMENTAL=1785181771 ADB_SERIAL=<wireless-ip:port> \
  ./lineageos/dipper/tools/qualify-runtime.sh
```

## Phase 5: Reproducibility

Status: complete.

- Regenerate every patch from the current live worktrees: complete.
- Remove stale and duplicate changes from the patch series: complete.
- Verify application to the exact audited LineageOS bases: complete.
- Verify that the patches recreate every current source file: complete.
- Run source gates, controlled builds and final artifact gates: complete.
- Record the installed R13 hash and runtime acceptance evidence: complete.
- Preserve the exact read-only OTA used for qualification: complete.
- Rebuild only if a future source change requires it.

## Phase 6: Release

Status: complete.

- Mark R13 qualified from the complete acceptance record: complete.
- Finalize status, audit, release notes and installation instructions:
  complete.
- Commit and push the reviewed CaCamOS sources to
  `https://github.com/LeMegaGeek/cacamos`: complete.
- Publish the exact verified OTA and checksum as CaCamOS 0.7.0: complete.

## Phase 7: Dedicated CaCamOS 1.0.0

Status: complete.

1. Replaced the general-purpose LineageOS user experience with the CaCamOS
   boot identity and DeviceAsWebcam-only HOME.
2. Removed the browser, gallery, music player, generic launcher, lock screen
   and consumer setup flow.
3. Retained authenticated wireless ADB maintenance while keeping the physical
   cable UVC-only.
4. Removed 360p and YUYV; qualified MJPEG 720p, 1024x576 and 1080p at 15 and
   30 FPS.
5. Added a valid MJPEG warmup frame before `STREAMON` to satisfy stock OBS's
   first-frame deadline.
6. Added bounded periodic UVC control-event draining to recover every rapid
   stream close/reopen.
7. Classified endpoint `ENODEV` and `ESHUTDOWN` as normal USB removal.
8. Passed stock OBS, Chromium/WebRTC, GStreamer, VLC, 100 rapid reopens, a
   sustained two-minute stream and five host USB resets.
9. Built and signed incremental `1785337449` with ten of sixteen cores,
   reserving six.
10. Qualified and published the exact CaCamOS 1.0.0 OTA and checksum.
