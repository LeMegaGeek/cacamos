# Current Mi 8 Audit

Audit date: 2026-07-27

## Required Product Behavior

CaCamOS on the Xiaomi Mi 8 (`dipper`) must:

- start without a lock on a fresh data partition;
- expose UVC alone on the USB cable and keep ADB on Wi-Fi;
- start the webcam service and open its preview automatically;
- enumerate on Linux and Windows as a standard UVC webcam;
- produce correctly oriented and correctly colored video in OBS;
- retain the accepted fixed 16:9 canvas and black portrait bars;
- deliver every advertised mode at its negotiated frame rate;
- survive stream stops, cable reconnects and reboots without freezing or
  restarting either the webcam process or the phone.

## Qualified R13 Build

The installed and qualified OTA is:

```text
lineage-22.2-20260727-UNOFFICIAL-CACAMOS-R13-dipper.zip
size=1223300465
sha256=efed9f1141514d1835bd8e48e6a5d7d04fa97fb0ab97083fd8df194f42c4a7a8
build_incremental=1785181771
```

The package signature, compiled payload, source tree and all eight reproducible
patches pass their automatic gates. The installed build reports the expected
incremental and survives a clean reboot with automatic UVC, preview, no-lock
and wireless ADB state restored.

## Validated Data Path

R13 enumerates on Linux as `18d1:4eed`. The host sees one UVC capture node and
one metadata node with this descriptor order:

1. MJPEG 1280x720 at 30 and 15 FPS;
2. MJPEG 640x360 at 30 and 15 FPS;
3. MJPEG 1920x1080 at 30 and 15 FPS;
4. YUYV 640x360 at 30 and 15 FPS.

The final R13 matrix was:

| Format | Size | Requested | Frames / elapsed | Measured |
| --- | --- | ---: | ---: | ---: |
| YUYV | 640x360 | 30 FPS | 300 / 10 s | passed |
| YUYV | 640x360 | 15 FPS | 150 / 10 s | passed |
| MJPEG | 640x360 | 30 FPS | 300 / 10 s | passed |
| MJPEG | 640x360 | 15 FPS | 150 / 10 s | passed |
| MJPEG | 1280x720 | 30 FPS | 300 / 10 s | passed |
| MJPEG | 1280x720 | 15 FPS | 150 / 10 s | passed |
| MJPEG | 1920x1080 | 30 FPS | 300 / 10 s | passed |
| MJPEG | 1920x1080 | 15 FPS | 150 / 10 s | passed |

Every raw frame had the expected YUYV length or valid JPEG boundaries and
decoded without error. The sustained MJPEG 1280x720 test delivered 18,000
intact frames in 605.752 seconds, or 29.72 FPS including startup, without a
freeze.

This proves the short-frame ownership fix, negotiated cadence, advertised mode
table, color conversion and ten-minute stream stability.

## Reconnect Qualification

R12 exposed a service-lifecycle failure after a physical cable disconnect:
Linux could still read the descriptors but `uvcvideo` timed out while Android
left a bound foreground service alive without a UVC listener.

```text
Failed to query (GET_INFO) UVC control ...: -110
Failed to initialize the device (-71)
```

Wireless ADB showed that `com.android.DeviceAsWebcam` and its foreground
service were still alive. The native log instead reported that the service was
already running or stopping each time the USB state receiver tried to start it.

The source and runtime state identified the exact lifecycle:

1. `UVC_EVENT_DISCONNECT` stopped the UVC listener and called `stopSelf()`.
2. The preview activity remained bound to the foreground service.
3. Android therefore could not destroy the service or run native teardown.
4. The reconnect receiver found the stale service and refused to start a new
   listener.
5. No userspace thread answered the host's UVC setup requests.

R13 handles a cable disconnect as stream teardown, not service teardown. The
listener keeps polling the persistent gadget fd and returns to control-event
mode. A separate preview-release callback handles the rarer case where the
gadget node itself is removed.

Two physical cable cycles returned a working Linux capture node without a phone
restart. Five additional host USB resets each returned 300 intact 720p frames
at 29.73 to 29.77 FPS. The phone boot ID, webcam PID and controller-thread
counts stayed unchanged.

OBS Studio 32.2.0 has a separate Linux reconnection detail: its udev callback
compares the configured source path literally. A source stored as
`/dev/v4l/by-id/...` does not match the `/dev/video0` remove/add event. Using
the direct `/dev/video0` path lets OBS detect removal and initially resume.
After repeated cycles, OBS can later stop receiving frames and requires a
restart. R13 is released with this known limitation.

## Image and Orientation Evidence

R12 front-camera portrait output was upright, but both landscape directions
were 180 degrees wrong. On the MI8 front sensor, the previous stream transform
used `sensor + deviceOrientation`. Portrait values happen to match, while both
landscape values are the exact opposite of the required transform.

R13 uses `sensor - deviceOrientation` for the front stream. Physical OBS
testing confirms upright front-camera portrait and landscape output. The phone
controls use `streamRotation - sensorOrientation`, keeping the `1.0` and `2.0`
labels upright with the physical device. Colors are correct, the former green
band is absent, camera switching works and the accepted black portrait bars
remain. Rear-camera behavior is unchanged.

## Appliance Paths

The current source retains the physically validated and audited paths for:

- UVC-only cable composition and suppression of unused USB FunctionFS retries;
- automatic ADB Wi-Fi re-enable after a network becomes available;
- direct-boot service startup and automatic preview launch;
- bounded camera open, capture-session and encoded-buffer waits;
- generation-safe callbacks and complete image cleanup;
- atomic native listener state and two-phase deadlock-free shutdown;
- nonblocking V4L2 discovery and failed-stream handshake release;
- real Android 4:2:0 plane conversion, output-stride restoration and JPEG
  boundary validation;
- 320 allocated gadget requests with 64 initially queued empty requests;
- controlled two-job builds with reserved cores and a memory watchdog.

## Startup and Access State

After installation and a clean reboot, R13 reports no credential, no active
lock screen and `deviceLocked=false`. It starts the webcam service and preview
automatically, exposes UVC alone on the cable, and enables secure ADB over
Wi-Fi once the network is available.

## Safety Finding

Android's `svc usb resetUsbGadget` is unsafe on this MI8 kernel and caused a
kernel panic during diagnostics. It is not used by the qualification tools.
Host-side `usbreset` and ordinary cable reconnects exercise UVC remove/add
without rebooting the phone.

## Result

R13 meets the core webcam, startup, orientation and sustained-stream targets.
Its qualification evidence is stored under `dist/cacam-os-qualifications/`.
Automatic long-lived OBS recovery after cable reconnection remains a known
limit of this release.
