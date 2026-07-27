# Current CaCamOS MI8 Status

Status date: 2026-07-27

## R13 Release

CaCamOS R13 is installed and physically validated on the Xiaomi Mi 8
(`dipper`). The exact OTA is:

```text
lineage-22.2-20260727-UNOFFICIAL-CACAMOS-R13-dipper.zip
size=1223300465
sha256=efed9f1141514d1835bd8e48e6a5d7d04fa97fb0ab97083fd8df194f42c4a7a8
build_incremental=1785181771
```

The archive is an independent read-only copy of the verified build output.
All eight patches reproduce the audited LineageOS worktrees. Source gates,
Java/Kotlin/C++ compilation, compiled-payload checks, archive integrity and the
whole-package signature pass.

## Runtime Evidence

The installed R13 build proves:

- successful boot of incremental `1785181771`;
- UVC alone on the USB cable, bound by the standard Linux `uvcvideo` driver;
- automatic webcam service and preview startup;
- no active credential or lock screen;
- automatic secure ADB-over-Wi-Fi startup after Wi-Fi becomes available;
- only the real 15 and 30 FPS modes are advertised;
- all MJPEG 360p, 720p and 1080p modes pass at 15 and 30 FPS;
- YUYV 360p passes at 15 and 30 FPS;
- every captured MJPEG frame has valid boundaries and decodes without error;
- every V4L2 sequence is continuous.

The final sustained R13 capture delivered 18,000 intact 1280x720 MJPEG frames
in 605.752 seconds, or 29.72 FPS including startup.

Five host-side USB resets then returned the capture node and delivered 300
intact 720p frames each at 29.73 to 29.77 FPS. The phone boot ID, webcam PID
and controller-thread counts remained unchanged.

## Image and Orientation

Physical OBS checks confirm:

- the previously inverted front-camera landscape position is upright;
- front-camera portrait remains upright;
- the `1.0` and `2.0` controls remain upright on the phone;
- colors are correct and the former green band is absent;
- the accepted fixed 16:9 output retains black bars in portrait;
- switching between the front and rear cameras works.

The rear-camera rotation path was already correct and is unchanged by R13.

## Known OBS Reconnection Limit

OBS Studio 32.2.0 on Linux compares the configured source path literally with
the udev path. Configure the CaCamOS source with its direct node, for example:

```text
/dev/video0
```

Do not configure that OBS source with
`/dev/v4l/by-id/usb-Xiaomi_Xiaomi_Mi_8_...`. The direct node lets OBS detect
USB removal and return immediately after reconnection. A later OBS capture
timeout can nevertheless leave the picture frozen. Restarting OBS restores the
stream. R13 is published with this known limitation.

## Safety

Do not use Android's `svc usb resetUsbGadget` on this MI8 kernel. That
diagnostic command can panic and reboot the phone. Runtime qualification uses
the host-side `usbreset` operation instead; ordinary cable disconnects and
host-side resets do not restart the phone.

## Installation Policy

CaCamOS MI8 installation uses Lineage Recovery and `adb sideload`. The verified
installer refuses an OTA until source, patch, compiled-payload and package
signature gates pass.
