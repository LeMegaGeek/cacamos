#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../.." && pwd)"
adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
matrix_duration="${MATRIX_DURATION:-30}"
matrix_attempts="${MATRIX_ATTEMPTS:-2}"
long_duration="${LONG_DURATION:-600}"
rebind_attempts="${REBIND_ATTEMPTS:-5}"
rebind_capture_duration="${REBIND_CAPTURE_DURATION:-10}"
usb_reset_target="${USB_RESET_TARGET:-18d1:4eed}"
run_stream_matrix="${RUN_STREAM_MATRIX:-1}"
run_long_capture="${RUN_LONG_CAPTURE:-1}"
run_usb_resets="${RUN_USB_RESETS:-1}"
run_application_tests="${RUN_APPLICATION_TESTS:-1}"
run_obs_test="${RUN_OBS_TEST:-1}"
run_rapid_reopen="${RUN_RAPID_REOPEN:-1}"
rapid_reopen_attempts="${RAPID_REOPEN_ATTEMPTS:-20}"
report_dir="${REPORT_DIR:-$project_root/dist/cacam-os-qualifications}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

require_positive_integer() {
    [[ "$2" =~ ^[1-9][0-9]*$ ]] || fail "$1 must be a positive integer"
}

require_boolean() {
    [[ "$2" == "0" || "$2" == "1" ]] || fail "$1 must be 0 or 1"
}

for command in "$adb_bin" fuser grep rg usbreset v4l2-ctl; do
    command -v "$command" >/dev/null 2>&1 || fail "missing command: $command"
done
for script in \
    find-cacamos-webcam.sh \
    test-host-applications.sh \
    test-host-obs.sh \
    test-host-uvc-reopen.sh \
    test-host-uvc-stream.sh \
    verify-webcam.sh; do
    [[ -x "$script_dir/$script" ]] || fail "missing executable: $script_dir/$script"
done
require_positive_integer MATRIX_DURATION "$matrix_duration"
require_positive_integer MATRIX_ATTEMPTS "$matrix_attempts"
require_positive_integer LONG_DURATION "$long_duration"
require_positive_integer REBIND_ATTEMPTS "$rebind_attempts"
require_positive_integer REBIND_CAPTURE_DURATION "$rebind_capture_duration"
require_positive_integer RAPID_REOPEN_ATTEMPTS "$rapid_reopen_attempts"
require_boolean RUN_STREAM_MATRIX "$run_stream_matrix"
require_boolean RUN_LONG_CAPTURE "$run_long_capture"
require_boolean RUN_USB_RESETS "$run_usb_resets"
require_boolean RUN_APPLICATION_TESTS "$run_application_tests"
require_boolean RUN_OBS_TEST "$run_obs_test"
require_boolean RUN_RAPID_REOPEN "$run_rapid_reopen"

if [[ -z "$adb_serial" ]]; then
    mapfile -t android_serials < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    [[ "${#android_serials[@]}" -eq 1 ]] ||
        fail "expected exactly one running ADB device, found ${#android_serials[@]}"
    adb_serial="${android_serials[0]}"
fi
[[ "$adb_serial" == *:* ]] ||
    fail "runtime qualification requires ADB over Wi-Fi, found $adb_serial"
export ADB_SERIAL="$adb_serial"
adb_cmd=("$adb_bin" -s "$adb_serial")

adb_exec() {
    "${adb_cmd[@]}" "$@"
}

wait_for_host_uvc() {
    local attempt candidate

    for ((attempt = 1; attempt <= 60; ++attempt)); do
        candidate="$("$script_dir/find-cacamos-webcam.sh" 2>/dev/null || true)"
        if [[ -n "$candidate" ]] &&
            v4l2-ctl --device="$candidate" --all >/dev/null 2>&1; then
            host_device="$candidate"
            return 0
        fi
        sleep 1
    done
    return 1
}

capture_process_state() {
    local label="$1"
    local pid

    pid="$(adb_exec shell pidof com.android.DeviceAsWebcam | tr -d '\r')"
    [[ "$pid" =~ ^[0-9]+$ ]] ||
        fail "DeviceAsWebcam is not running while capturing $label state"
    adb_exec shell ps -T -p "$pid" >"$run_dir/threads-$label.txt"
    adb_exec shell dumpsys meminfo com.android.DeviceAsWebcam \
        >"$run_dir/meminfo-$label.txt"
}

assert_single_controller_threads() {
    local thread count
    local threads_file="$1"

    for thread in CaCamFrameRead CaCamCallbacks CaCamSvcEvents; do
        count="$(awk -v name="$thread" '$NF == name { count++ } END { print count + 0 }' \
            "$threads_file")"
        [[ "$count" -eq 1 ]] ||
            fail "expected one $thread thread, found $count in $(basename "$threads_file")"
    done
    count="$(awk '$NF == "CaCamImgWriter" { count++ } END { print count + 0 }' \
        "$threads_file")"
    [[ "$count" -le 1 ]] ||
        fail "camera-unavailable image writer leaked across reconnects"
}

mkdir -p "$report_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
run_dir="$report_dir/${timestamp}-runtime"
mkdir -p "$run_dir"
summary="$run_dir/summary.txt"
exec > >(tee "$summary") 2>&1

printf 'CaCamOS sustained runtime qualification\n'
printf 'date=%s\n' "$(date -Is)"
printf 'adb_target=%s\n' "$adb_serial"
printf 'evidence=%s\n' "$run_dir"
printf 'run_stream_matrix=%s\n' "$run_stream_matrix"
printf 'run_long_capture=%s\n' "$run_long_capture"
printf 'run_usb_resets=%s\n' "$run_usb_resets"
printf 'run_application_tests=%s\n' "$run_application_tests"
printf 'run_obs_test=%s\n' "$run_obs_test"
printf 'run_rapid_reopen=%s\n' "$run_rapid_reopen"

"$script_dir/verify-webcam.sh" "$run_dir"

host_device="$("$script_dir/find-cacamos-webcam.sh")"
if fuser "$host_device" >/dev/null 2>&1; then
    fail "$host_device is already in use; close every camera application before qualification"
fi

boot_id_before="$(adb_exec shell cat /proc/sys/kernel/random/boot_id | tr -d '\r')"
pid_before="$(adb_exec shell pidof com.android.DeviceAsWebcam | tr -d '\r')"
[[ "$pid_before" =~ ^[0-9]+$ ]] || fail "DeviceAsWebcam is not running"
capture_process_state baseline
assert_single_controller_threads "$run_dir/threads-baseline.txt"

# Isolate all errors below to this qualification run.
adb_exec logcat -b all -c

printf '\nADB USB transport idle check\n'
sleep 10
adb_exec logcat -b all -d -v threadtime >"$run_dir/functionfs-idle-log.txt"
functionfs_idle_timeouts="$(
    grep -Fc 'timed out while waiting for FUNCTIONFS_BIND' \
        "$run_dir/functionfs-idle-log.txt" || true
)"
[[ "$functionfs_idle_timeouts" -le 1 ]] ||
    fail "adbd repeated its unused USB FunctionFS bind $functionfs_idle_timeouts times in 10 seconds"
adb_exec logcat -b all -c

if [[ "$run_rapid_reopen" -eq 1 ]]; then
    printf '\nRapid UVC close/reopen regression\n'
    RAPID_REOPEN_ATTEMPTS="$rapid_reopen_attempts" V4L2_DEVICE="$host_device" \
        "$script_dir/test-host-uvc-reopen.sh" "$run_dir"
fi

if [[ "$run_application_tests" -eq 1 ]]; then
    printf '\nStandard desktop and WebRTC applications\n'
    V4L2_DEVICE="$host_device" \
        "$script_dir/test-host-applications.sh" "$run_dir/applications"
fi

if [[ "$run_obs_test" -eq 1 ]]; then
    printf '\nStock OBS V4L2 source\n'
    V4L2_DEVICE="$host_device" \
        "$script_dir/test-host-obs.sh" "$run_dir/applications"
fi

if [[ "$run_stream_matrix" -eq 1 ]]; then
    printf '\nComplete advertised-mode matrix\n'
    mode_matrix=(
        "MJPG 1280 720 30"
        "MJPG 1280 720 15"
        "MJPG 1024 576 30"
        "MJPG 1024 576 15"
        "MJPG 1920 1080 30"
        "MJPG 1920 1080 15"
    )
    for mode in "${mode_matrix[@]}"; do
        read -r pixel_format width height fps <<<"$mode"
        PIXEL_FORMAT="$pixel_format" WIDTH="$width" HEIGHT="$height" FPS="$fps" \
            V4L2_DEVICE="$host_device" \
            "$script_dir/test-host-uvc-stream.sh" \
            "$matrix_duration" "$matrix_attempts"
    done
fi

if [[ "$run_long_capture" -eq 1 ]]; then
    printf '\n720p MJPEG 30 FPS sustained capture\n'
    PIXEL_FORMAT=MJPG WIDTH=1280 HEIGHT=720 FPS=30 V4L2_DEVICE="$host_device" \
        "$script_dir/test-host-uvc-stream.sh" "$long_duration" 1
fi

if [[ "$run_usb_resets" -eq 1 ]]; then
    printf '\nAutomated host USB port resets\n'
    for ((rebind = 1; rebind <= rebind_attempts; ++rebind)); do
        printf 'USB reset %s/%s\n' "$rebind" "$rebind_attempts"
        usbreset "$usb_reset_target"
        wait_for_host_uvc ||
            fail "the MI8 UVC node did not return after host USB reset $rebind"
        PIXEL_FORMAT=MJPG WIDTH=1280 HEIGHT=720 FPS=30 V4L2_DEVICE="$host_device" \
            "$script_dir/test-host-uvc-stream.sh" "$rebind_capture_duration" 1
        capture_process_state "rebind-$rebind"
        assert_single_controller_threads "$run_dir/threads-rebind-$rebind.txt"
    done
fi

adb_exec logcat -b all -d -v threadtime >"$run_dir/phone-logcat.txt"
adb_exec logcat -b kernel -d -v threadtime >"$run_dir/phone-kernel-log.txt"
adb_exec shell dumpsys usb >"$run_dir/dumpsys-usb.txt"
adb_exec shell dumpsys activity services com.android.DeviceAsWebcam \
    >"$run_dir/dumpsys-webcam-service.txt"

boot_id_after="$(adb_exec shell cat /proc/sys/kernel/random/boot_id | tr -d '\r')"
pid_after="$(adb_exec shell pidof com.android.DeviceAsWebcam | tr -d '\r')"
[[ "$boot_id_after" == "$boot_id_before" ]] ||
    fail "the phone rebooted during qualification"
[[ "$pid_after" == "$pid_before" ]] ||
    fail "DeviceAsWebcam restarted during qualification"

if rg -i \
    'aborted incomplete frame|timed out waiting for an encoded camera frame|camera frame production stopped|VIDIOC_DQBUF failed|Failed to dequeue V4L2 event|JPEG compression failed|Encoder produced an invalid JPEG|timed out while shutting down the camera controller|camera controller cleanup failed|ImageReader thread did not stop cleanly|forcing shutdown of .* executor|Fatal signal|ANR in com.android.DeviceAsWebcam' \
    "$run_dir/phone-logcat.txt" "$run_dir/phone-kernel-log.txt"; then
    fail "phone logs contain a stream-integrity or process failure"
fi

functionfs_rebind_timeouts="$(
    grep -Fc 'timed out while waiting for FUNCTIONFS_BIND' \
        "$run_dir/phone-logcat.txt" || true
)"
max_functionfs_rebind_timeouts=$((rebind_attempts + 2))
[[ "$functionfs_rebind_timeouts" -le "$max_functionfs_rebind_timeouts" ]] ||
    fail "adbd repeated USB FunctionFS binding $functionfs_rebind_timeouts times during qualification"

"$script_dir/verify-webcam.sh" "$run_dir"

printf '\nPASS: all requested runtime qualification stages passed.\n'
printf 'Evidence: %s\n' "$run_dir"
