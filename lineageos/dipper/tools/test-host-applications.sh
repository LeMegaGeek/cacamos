#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
report_dir="${1:-$(mktemp -d "${TMPDIR:-/tmp}/cacamos-apps.XXXXXX")}"
device="${V4L2_DEVICE:-}"
width="${WIDTH:-1280}"
height="${HEIGHT:-720}"
fps="${FPS:-30}"
vlc_seconds="${VLC_SECONDS:-6}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in fuser google-chrome gst-launch-1.0 python3 rg timeout vlc; do
    command -v "$command" >/dev/null 2>&1 || fail "missing command: $command"
done
for helper in find-cacamos-webcam.sh webrtc-probe.py webrtc-probe.html; do
    [[ -e "$script_dir/$helper" ]] || fail "missing helper: $script_dir/$helper"
done
for value_name in width height fps vlc_seconds; do
    value="${!value_name}"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "$value_name must be a positive integer"
done

if [[ -z "$device" ]]; then
    device="$("$script_dir/find-cacamos-webcam.sh")"
fi
[[ -e "$device" ]] || fail "capture node is missing: $device"
if fuser "$device" >/dev/null 2>&1; then
    fail "$device is already in use"
fi
mkdir -p "$report_dir"

printf 'WebRTC / Chromium getUserMedia\n'
python3 "$script_dir/webrtc-probe.py" \
    --chrome "$(command -v google-chrome)" \
    --html "$script_dir/webrtc-probe.html" \
    --report "$report_dir/webrtc.json"
printf 'PASS: Chromium consumed CaCamOS through the standard WebRTC camera API.\n'

printf '\nGStreamer V4L2 pipeline\n'
timeout -k 5 20 gst-launch-1.0 -q \
    v4l2src device="$device" io-mode=mmap num-buffers=$((fps * 4)) \
    ! "image/jpeg,width=$width,height=$height,framerate=$fps/1" \
    ! jpegparse ! jpegdec ! fakesink sync=true \
    >"$report_dir/gstreamer.log" 2>&1
printf 'PASS: GStreamer opened and decoded the standard V4L2 source.\n'

printf '\nVLC V4L2 pipeline\n'
set +e
timeout -k 3 "$vlc_seconds" vlc -vv -I dummy \
    --no-audio --vout=dummy --no-video-title-show \
    "v4l2://$device:chroma=MJPG:width=$width:height=$height:fps=$fps" \
    >"$report_dir/vlc.log" 2>&1
vlc_status="$?"
set -e
if [[ "$vlc_status" -ne 0 && "$vlc_status" -ne 124 ]]; then
    tail -80 "$report_dir/vlc.log" >&2
    fail "VLC exited with status $vlc_status"
fi
for marker in \
    "selected format MJPG" \
    "requested frame size: ${width}x${height}" \
    "frame rate: ${fps}/1" \
    "codec (mjpeg) started" \
    "successfully opened"; do
    rg -Fq "$marker" "$report_dir/vlc.log" ||
        fail "VLC did not confirm: $marker"
done
if rg -i \
    'cannot open.*video|cannot start streaming|device or resource busy|decoder error|buffer deadlock' \
    "$report_dir/vlc.log"; then
    fail "VLC reported a capture or decode failure"
fi
printf 'PASS: VLC opened and decoded the standard V4L2 source.\n'

printf '\nPASS: standard browser and desktop media applications accepted CaCamOS.\n'
printf 'Evidence: %s\n' "$report_dir"
