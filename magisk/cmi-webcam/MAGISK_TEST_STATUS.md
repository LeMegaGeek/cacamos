# Magisk Test Status

Date: 2026-07-01

## Current Phone

```text
ro.product.device=cmi
ro.product.model=Mi 10 Pro
ro.lineage.version=23.2-20260626-NIGHTLY-cmi
```

Normal boot state:

```text
su=<not available>
Magisk app=v30.7 installed
Magisk root=<not active on normal boot>
ro.usb.uvc.enabled=<unset>
```

## Matching Boot Image

The official LineageOS `20260626` build was downloaded and the matching
`boot.img` was extracted:

```text
lineage-23.2-20260626-nightly-cmi-boot.img
sha256=a8baf6bef7304423911f42b70b53e0b6abf63eff995b356305ee3f5f44c08d5c
Magisk=v30.7
```

The boot image patches successfully on-device through non-root ADB shell using
Magisk's official `boot_patch.sh` and arm64 binaries.

Generated files:

```text
dist/magisk-test/lineage-23.2-20260626-nightly-cmi-boot.img
dist/magisk-test/lineage-23.2-20260626-nightly-cmi-boot-magisk-v30.7-patched.img
dist/magisk-test/lineage-23.2-20260626-nightly-cmi-magisk-test.txt
dist/magisk-test/lineage-23.2-20260626-nightly-cmi-signed.zip
```

## Temporary Boot Result

Temporary booting the matching patched image works and does not flash the phone.
On this build, Magisk root is exposed as:

```text
/debug_ramdisk/su
```

The helper scripts now test both:

```text
su
/debug_ramdisk/su
```

## Runtime UVC Result

The rooted runtime test can set `ro.usb.uvc.enabled=true` with Magisk
`resetprop`, but the stock Nightly still falls back to `adb` after a
`uvc,adb` USB request. That makes the Magisk path useful for diagnostics, not
yet a replacement for the ROM build path.

## Next Safe Step

Build and flash a LineageOS `cmi` image with the CaCam OS source addon so that
`ro.usb.uvc.enabled=true` exists from boot, then verify host-side enumeration:

```bash
v4l2-ctl --list-devices
```

Completion requires the host to list the Mi 10 Pro as a UVC/video capture
device.
