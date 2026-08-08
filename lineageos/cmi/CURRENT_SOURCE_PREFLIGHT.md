# Current MI10 Pro Source Status

Date: 2026-08-08

Workspace:

```text
/home/denis/Documents/Denis/dev/lineage-cmi
```

## Result

- Full LineageOS 23.2 / Android 16 `cmi` workspace synchronized.
- Dedicated CaCamOS version: `1.2.1`.
- Fourteen-project source port complete.
- Exact-base patch verification passes for every project.
- Applying the published patches recreates every audited worktree exactly.
- The complete CaCamOS source invariant verifier passes.
- The signed 1.2.1 OTA passes source, payload, identity, archive and signature
  verification under the controlled six-worker profile.
- Recovery maintenance ADB is enabled for appliance builds, and a failed mount
  of optional `/cache` no longer aborts ADB sideload before reading the OTA.
- Physical idle-energy and touch-wake qualification passed on the MI10 Pro.
  The display slept after 30 seconds, idle camera and audio activity stopped,
  an active 2,400-frame UVC stream survived display sleep, and a physical
  double-tap restored the webcam interface.

## Published Source Areas

```text
device/xiaomi/cmi
frameworks/base
packages/services/DeviceAsWebcam
kernel/xiaomi/sm8250
system/sepolicy
vendor/qcom/opensource/usb
packages/apps/Settings
packages/modules/adb
vendor/lineage
build/make
bootable/recovery
system/core
build/soong
build/blueprint
```

The baseline stock audit remains in `CURRENT_DEVICE_AUDIT.md`; it explains why
ordinary LineageOS does not enable the complete CaCamOS appliance behavior.
