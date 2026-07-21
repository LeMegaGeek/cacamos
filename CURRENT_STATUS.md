# Current CaCamOS MI8 Status

Status date: 2026-07-21

## Working State

- The active LineageOS source tree remains in
  `/home/denis/Documents/Denis/dev/lineage-dipper`.
- The latest test ROM is installed on the Xiaomi Mi 8 (`dipper`).
- Webcam mode is selected automatically at startup.
- Linux enumerates the phone as a standard UVC webcam.
- OBS opens the device and has streamed more than 1,500 frames continuously at
  about 30 FPS.
- The first-frame startup timeout was fixed by queuing the first UVC buffer
  before `VIDIOC_STREAMON` in `UVCProvider.cpp`.

Latest installed OTA artifact:

```text
/home/denis/Documents/Denis/dev/lineage-dipper/out/target/product/dipper/lineage_dipper-ota.zip
sha256=e64d185ff17a0eac7a1c8e55050aa300cb0d26c69d896e4fca4af1292cddec7c
```

## Remaining Image Defects

The UVC stream is stable, but it is not visually correct yet:

- the camera image is rotated by 90 degrees;
- a green band appears along one edge;
- colors are incorrect;
- restarting UVC immediately after OBS closes can still return `EIO`.

The next investigation point is
`packages/services/DeviceAsWebcam/interface/src/Encoder.cpp`. Its current I420
conversion handles only 0 and 180 degree rotations and uses configured stream
dimensions instead of the actual camera `HardwareBuffer` dimensions. Rotation,
crop, stride, pixel format and UV plane ordering must be verified together.

## Active Source Changes

The current LineageOS workspace contains CaCamOS work in these repositories:

```text
frameworks/base
packages/services/DeviceAsWebcam
kernel/xiaomi/sdm845
system/sepolicy
device/xiaomi/dipper
```

Do not reset those repositories when resuming. The source workspace is kept
separate from this addon repository because a full LineageOS checkout and its
build outputs are much larger than CaCamOS itself.

