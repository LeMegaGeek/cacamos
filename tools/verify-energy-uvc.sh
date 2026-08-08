#!/usr/bin/env bash
set -euo pipefail

adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
expected_version="${EXPECTED_CACAMOS_VERSION:-}"
video_device="${V4L2_DEVICE:-}"
width="${WIDTH:-1280}"
height="${HEIGHT:-720}"
fps="${FPS:-30}"
idle_seconds="${IDLE_SECONDS:-42}"
duration_seconds="${DURATION_SECONDS:-80}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in "$adb_bin" awk grep rg timeout udevadm v4l2-ctl; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is unavailable"
done
for value_name in width height fps idle_seconds duration_seconds; do
    value="${!value_name}"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$value_name must be positive"
done
(( duration_seconds > idle_seconds + 5 )) ||
    fail "DURATION_SECONDS must exceed IDLE_SECONDS by more than five seconds"

if [[ -z "$adb_serial" ]]; then
    mapfile -t devices < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    [[ "${#devices[@]}" -eq 1 ]] ||
        fail "set ADB_SERIAL when more than one Android device is connected"
    adb_serial="${devices[0]}"
fi

adb_cmd=("$adb_bin" -s "$adb_serial")
adb_shell() {
    "${adb_cmd[@]}" shell "$@" 2>/dev/null | tr -d '\r'
}

[[ "$("${adb_cmd[@]}" get-state 2>/dev/null | tr -d '\r')" == "device" ]] ||
    fail "$adb_serial is not available"
device="$(adb_shell getprop ro.product.device)"
version="$(adb_shell getprop ro.cacamos.version)"
android_serial="$(adb_shell getprop ro.serialno)"
[[ "$device" == "dipper" || "$device" == "cmi" ]] ||
    fail "unsupported device: ${device:-unset}"
if [[ -n "$expected_version" && "$version" != "$expected_version" ]]; then
    fail "expected CaCamOS $expected_version, found $version"
fi

if [[ -z "$video_device" ]]; then
    candidates=()
    shopt -s nullglob
    for node in /dev/video*; do
        properties="$(udevadm info --query=property --name="$node" 2>/dev/null || true)"
        grep -Fxq 'ID_VENDOR_ID=18d1' <<<"$properties" || continue
        grep -Fxq 'ID_MODEL_ID=4eef' <<<"$properties" || continue
        grep -Eq '^ID_V4L_CAPABILITIES=.*:capture:' <<<"$properties" || continue
        if [[ -n "$android_serial" ]]; then
            grep -Eq "^(ID_SERIAL_SHORT=${android_serial}|ID_SERIAL=.*_${android_serial})$" \
                <<<"$properties" || continue
        fi
        candidates+=("$node")
    done
    shopt -u nullglob
    [[ "${#candidates[@]}" -eq 1 ]] ||
        fail "expected one CaCamOS capture node for serial $android_serial, found ${#candidates[@]}"
    video_device="${candidates[0]}"
fi
[[ -c "$video_device" ]] || fail "invalid capture node: $video_device"

timestamp="$(date +%Y%m%d-%H%M%S)"
report_dir="${REPORT_DIR:-$(pwd)/dist/cacam-os-qualifications/${timestamp}-${device}-screenoff-uvc}"
mkdir -p "$report_dir"
stream_log="$report_dir/v4l2-stream.log"
summary="$report_dir/summary.txt"
frame_count=$((duration_seconds * fps))
timeout_seconds=$((duration_seconds + 30))
stream_pid=""

cleanup() {
    if [[ -n "$stream_pid" ]] && kill -0 "$stream_pid" 2>/dev/null; then
        kill "$stream_pid" 2>/dev/null || true
        wait "$stream_pid" 2>/dev/null || true
    fi
    adb_shell input keyevent KEYCODE_WAKEUP >/dev/null || true
}
trap cleanup EXIT INT TERM

adb_shell input keyevent KEYCODE_WAKEUP >/dev/null
adb_shell am start -W -n \
    com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamPreview \
    >/dev/null
sleep 2

timeout -k 5 "$timeout_seconds" v4l2-ctl --device="$video_device" \
    --set-fmt-video="width=$width,height=$height,pixelformat=MJPG" \
    --set-parm="$fps" \
    --stream-mmap=8 \
    --stream-count="$frame_count" \
    --stream-to=/dev/null \
    --verbose >"$stream_log" 2>&1 &
stream_pid=$!

sleep "$idle_seconds"
kill -0 "$stream_pid" 2>/dev/null || fail "UVC stopped before display sleep"

power_dump="$(adb_shell dumpsys power)"
display_dump="$(adb_shell dumpsys display)"
if ! grep -Fq 'mWakefulness=Asleep' <<<"$power_dump" &&
    ! grep -Fq 'mScreenState=OFF' <<<"$display_dump"; then
    fail "the display remained on during the host UVC stream"
fi
webcam_pid="$(adb_shell pidof com.android.DeviceAsWebcam)"
[[ "$webcam_pid" =~ ^[0-9]+$ ]] || fail "DeviceAsWebcam stopped with the display"

wait "$stream_pid" || fail "UVC failed while the display was off"
stream_pid=""
captured="$(grep -c '^cap dqbuf:' "$stream_log" || true)"
[[ "$captured" -eq "$frame_count" ]] ||
    fail "captured $captured/$frame_count frames"
if rg -i 'timed out|input/output error|VIDIOC_STREAMON.*failed' "$stream_log"; then
    fail "the UVC log contains a transport failure"
fi

{
    printf 'device=%s\n' "$device"
    printf 'version=%s\n' "$version"
    printf 'android_serial=%s\n' "$android_serial"
    printf 'adb_target=%s\n' "$adb_serial"
    printf 'video_device=%s\n' "$video_device"
    printf 'mode=%sx%s@%s MJPG\n' "$width" "$height" "$fps"
    printf 'display_off_after_seconds=%s\n' "$idle_seconds"
    printf 'captured_frames=%s\n' "$captured"
    printf 'requested_frames=%s\n' "$frame_count"
    printf 'result=PASS\n'
} | tee "$summary"

printf 'PASS: UVC remained complete while the CaCamOS display slept.\n'
printf 'Evidence: %s\n' "$report_dir"
