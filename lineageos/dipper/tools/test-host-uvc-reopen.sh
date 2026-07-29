#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
report_dir="${1:-$(mktemp -d "${TMPDIR:-/tmp}/cacamos-uvc-reopen.XXXXXX")}"
device="${V4L2_DEVICE:-}"
attempts="${RAPID_REOPEN_ATTEMPTS:-20}"
frames="${RAPID_REOPEN_FRAMES:-5}"
width="${WIDTH:-1280}"
height="${HEIGHT:-720}"
fps="${FPS:-30}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in rg timeout v4l2-ctl; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done
for value_name in attempts frames width height fps; do
    value="${!value_name}"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "$value_name must be a positive integer"
done
if [[ -z "$device" ]]; then
    device="$("$script_dir/find-cacamos-webcam.sh")"
fi
[[ -e "$device" ]] || fail "capture node is missing: $device"

work_dir="$report_dir/rapid-reopen"
mkdir -p "$work_dir"
printf 'Rapid UVC close/reopen: %s cycles, %s real frames per cycle\n' \
    "$attempts" "$frames"

for ((attempt = 1; attempt <= attempts; ++attempt)); do
    log="$work_dir/attempt-${attempt}.v4l2.log"
    if ! timeout -k 2 15 \
        v4l2-ctl --device="$device" \
        --set-fmt-video="width=$width,height=$height,pixelformat=MJPG" \
        --set-parm="$fps" \
        --stream-mmap=8 \
        --stream-count="$frames" \
        --stream-to=/dev/null \
        --verbose >"$log" 2>&1; then
        tail -80 "$log" >&2
        fail "rapid reopen cycle $attempt/$attempts failed; evidence: $work_dir"
    fi
done

for ((attempt = 1; attempt <= attempts; ++attempt)); do
    log="$work_dir/attempt-${attempt}.v4l2.log"
    captured="$(grep -c '^cap dqbuf:' "$log" || true)"
    [[ "$captured" -eq "$frames" ]] ||
        fail "cycle $attempt captured $captured/$frames frames; evidence: $work_dir"
    if rg -i 'timed out|input/output error|VIDIOC_STREAMON.*failed' "$log"; then
        fail "cycle $attempt reported a UVC control failure; evidence: $work_dir"
    fi
done

printf 'PASS: rapid close/reopen preserved every UVC STREAMON event.\n'
printf 'Evidence: %s\n' "$work_dir"
