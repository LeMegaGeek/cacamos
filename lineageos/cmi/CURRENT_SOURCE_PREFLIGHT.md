# Current cmi Source Preflight

Date: 2026-07-01

Workspace checked:

```text
/home/denis/Documents/Denis/dev/lineage-cmi
```

Status:

- LineageOS branch: `lineage-23.2`
- Local manifest: `cacam-os-cmi.xml`
- Minimal webcam source dependencies synced.
- `frameworks/base` synced locally.
- CaCam OS `cmi` patch applied to the workspace.
- `check-lineage-source-preflight.sh` passes without `--allow-partial`.
- `verify-source-tree.sh` passes on the patched workspace.

Verified source pieces:

- `DeviceAsWebcam` package is present.
- `device/xiaomi/cmi/device.mk` includes `DeviceAsWebcam`.
- `device/xiaomi/cmi/device.mk` sets `ro.usb.uvc.enabled=true`.
- CaCam OS DeviceAsWebcam overlay files are present.
- `frameworks/base` exposes `USB_FUNCTION_UVC`.
- QTI USB gadget HAL handles `GadgetFunction::UVC`, links `uvc.0`, and checks
  `ro.usb.uvc.enabled`.
- SELinux allows `hal_usb_gadget_server` to read `usb_uvc_enabled_prop`.
- `kernel/xiaomi/sm8250` config enables:

```text
CONFIG_MEDIA_USB_SUPPORT=y
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_CONFIGFS_F_UVC=y
```

Remaining proof required:

- Complete full LineageOS sync for a buildable ROM tree.
- Install missing host build packages.
- Build and flash the ROM.
- Prove host-side UVC enumeration with `v4l2-ctl --list-devices`.
- Check OBS or another host application sees the phone as a regular webcam.
