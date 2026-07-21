# Current Mi 8 Audit

Audit date: 2026-07-21

## Installed State

- Device: Xiaomi Mi 8 (`dipper`)
- Base: LineageOS `22.2`
- USB default after user unlock: UVC-only Webcam mode
- Linux host: enumerates the phone as a standard UVC webcam
- OBS: receives a continuous stream at about 30 FPS
- Last validated OTA SHA-256:
  `e64d185ff17a0eac7a1c8e55050aa300cb0d26c69d896e4fca4af1292cddec7c`

The OBS first-frame timeout was fixed by queueing the first filled V4L2 buffer
before completing `VIDIOC_STREAMON`. A validation session received more than
1,500 consecutive frames without the previous immediate timeout.

## Remaining Defects

- The picture is rotated by 90 degrees.
- Colors are incorrect.
- A green band is visible along one edge.
- Restarting UVC after OBS closes can still return `EIO` until the USB function
  is reset.

The next source investigation starts in
`packages/services/DeviceAsWebcam/interface/jni/Encoder.cpp`. Its current
conversion path handles only 0- and 180-degree rotation, and uses configured
dimensions where the actual hardware-buffer dimensions may be required. This
is the leading explanation for the rotation and chroma/stride symptoms; it is
not yet a confirmed fix.

## Reproducible Source State

The `patches/` series captures the full current MI8 delta from the LineageOS
`lineage-22.2` baselines:

```text
0001-dipper-device-webcam.patch
0002-frameworks-base-webcam-default.patch
0003-device-as-webcam-uvc.patch
0004-sdm845-uvc-gadget.patch
0005-system-server-uvc-sepolicy.patch
```

This includes UVC-only automatic startup, DeviceAsWebcam negotiation and
first-frame handling, the MI8 kernel UVC lifecycle changes, and required
SELinux access. The local LineageOS workspace remains separate from this
repository and retains its working branches for continued debugging.
