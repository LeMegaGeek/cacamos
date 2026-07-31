# CaCamOS 1.2.0 MI10 Pro Acceptance

Acceptance date: 2026-07-31

Target: Xiaomi Mi 10 Pro (`cmi`), LineageOS 23.2 / Android 16.

## Accepted Scope

| Gate | Evidence | Result |
| --- | --- | --- |
| Dedicated appliance product | `ro.cacamos.version=1.2.0`, appliance graph and cmi overlays in patch 0001 | Passed |
| Reproducible source | Fourteen exact-base patches recreate all audited Android worktrees | Passed |
| Source invariants | `tools/verify-source-tree.sh` | Passed |
| Standard USB video | UVC gadget, robust request pipeline and DeviceAsWebcam integration | Passed |
| Standard USB audio | UAC2 gadget plus Android microphone/speaker bridge | Passed |
| Windows interoperability | User test on the physical MI10 Pro | Passed |
| Controlled host resources | Ten-worker build profile, six reserved cores, memory watchdog | Passed |

## USB Behavior

The physical cable is reserved for standard UVC video and UAC2 audio. Normal
operation does not depend on BGOBS, a CaCamOS host application or a network
stream. Authenticated ADB maintenance remains on Wi-Fi.

Advertised video modes:

| Resolution | Frame rates |
| --- | --- |
| 1280x720 | 15, 30 FPS |
| 1024x576 | 15, 30 FPS |
| 1920x1080 | 15, 30 FPS |

The Snapdragon 865 provides more headroom than the MI8 platform, while the
published ordinary Camera2/UVC path remains capped at the verified 30 FPS.
Advertising 60 FPS would require a separate constrained-high-speed capture
session and is intentionally outside this release.

## Reproduction

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineage-cmi
./lineageos/cmi/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineage-cmi
./lineageos/cmi/tools/verify-source-tree.sh /path/to/lineage-cmi
```

The exact upstream commits for all fourteen Android projects are recorded in
`tools/verify-patch-series.sh`.
