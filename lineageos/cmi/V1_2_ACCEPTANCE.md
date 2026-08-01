# CaCamOS 1.2.0 MI10 Pro Acceptance Status

Status date: 2026-08-01

Target: Xiaomi Mi 10 Pro (`cmi`), LineageOS 23.2 / Android 16.

## Accepted Scope

| Gate | Evidence | Result |
| --- | --- | --- |
| Dedicated appliance product | `ro.cacamos.version=1.2.0`, appliance graph and cmi overlays in patch 0001 | Passed |
| Reproducible source | Fourteen exact-base patches recreate all audited Android worktrees | Passed |
| Source invariants | `tools/verify-source-tree.sh` | Passed |
| Full OTA build | `lineage_cmi-ota.zip`, 1,422,445,300 bytes, SHA-256 `6543738bfcc6ce4d9bce233677f8b68919cbf324e2843c42cb65f956d2abc649` | Passed |
| Standard USB video | Linux recognized `Mi 10 Pro: UVC Camera`; 720p, 1024x576 and 1080p at 30 FPS captured successfully, including 120 seconds at 1080p | Passed on the first 1.2.0 installation; final OTA regression pending |
| Standard USB audio | Linux recognized UAC2 microphone and speaker; 48 kHz mono capture and an acoustic 1 kHz speaker-return test passed | Passed on the first 1.2.0 installation; final OTA regression pending |
| Appliance runtime | Webcam preview at HOME, no consumer applications, no active credential, wireless ADB and UVC-only cable ownership | Passed on the first 1.2.0 installation; final identity regression pending |
| Matching recovery | Final OTA contains and directly installs the CaCamOS recovery signed for future CaCamOS updates | Package passed; physical installation pending |
| Windows interoperability | Physical test on the MI10 Pro | Pending |
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

The final identity/recovery-corrected OTA still requires installation on the
physical MI10 Pro. The runtime results above were measured on the immediately
preceding 1.2.0 package, whose video and audio implementation is identical.

## Reproduction

```bash
./lineageos/cmi/tools/install-into-lineage.sh /path/to/lineage-cmi
./lineageos/cmi/tools/verify-patch-series.sh \
  --match-worktrees /path/to/lineage-cmi
./lineageos/cmi/tools/verify-source-tree.sh /path/to/lineage-cmi
```

The exact upstream commits for all fourteen Android projects are recorded in
`tools/verify-patch-series.sh`.
