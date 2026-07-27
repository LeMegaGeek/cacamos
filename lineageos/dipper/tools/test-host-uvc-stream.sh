#!/usr/bin/env bash
set -euo pipefail

duration="${1:-60}"
attempts="${2:-3}"
fps="${FPS:-30}"
width="${WIDTH:-1280}"
height="${HEIGHT:-720}"
pixel_format="${PIXEL_FORMAT:-MJPG}"
device="${V4L2_DEVICE:-}"
min_fps_ratio="${MIN_FPS_RATIO:-0.90}"
max_fps_ratio="${MAX_FPS_RATIO:-1.10}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in v4l2-ctl timeout python3 ffmpeg ffprobe stat; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done

if [[ -z "$device" ]]; then
    shopt -s nullglob
    candidates=(/dev/v4l/by-id/usb-Xiaomi_Xiaomi_Mi_8_*video-index0)
    shopt -u nullglob
    [[ "${#candidates[@]}" -eq 1 ]] ||
        fail "expected one Xiaomi MI 8 capture node, found ${#candidates[@]}"
    device="${candidates[0]}"
fi

for value_name in duration attempts fps width height; do
    value="${!value_name}"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "$value_name must be a positive integer"
done
case "$pixel_format" in
    MJPG|YUYV)
        ;;
    *)
        fail "PIXEL_FORMAT must be MJPG or YUYV"
        ;;
esac
[[ -e "$device" ]] || fail "capture node is missing: $device"

frame_count=$((duration * fps))
timeout_seconds=$((duration * 2 + 20))
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cacamos-uvc-test.XXXXXX")"
keep_work_dir=0

cleanup() {
    if [[ "$keep_work_dir" -eq 0 ]]; then
        rm -rf "$work_dir"
    fi
}
trap cleanup EXIT

printf 'Device: %s\n' "$device"
printf 'Mode: %sx%s %s at %s fps\n' "$width" "$height" "$pixel_format" "$fps"
printf 'Validation: %s attempt(s), %s seconds and %s frames each\n' \
    "$attempts" "$duration" "$frame_count"

for ((attempt = 1; attempt <= attempts; ++attempt)); do
    capture="$work_dir/attempt-${attempt}.${pixel_format,,}"
    capture_log="$work_dir/attempt-${attempt}.v4l2.log"
    decode_log="$work_dir/attempt-${attempt}.ffmpeg.log"
    start_ns="$(date +%s%N)"

    if ! timeout -k 5 "$timeout_seconds" \
        v4l2-ctl --device="$device" \
        --set-fmt-video="width=$width,height=$height,pixelformat=$pixel_format" \
        --set-parm="$fps" \
        --stream-mmap=16 \
        --stream-count="$frame_count" \
        --stream-to="$capture" \
        --verbose >"$capture_log" 2>&1; then
        keep_work_dir=1
        tail -60 "$capture_log" >&2
        fail "capture attempt $attempt/$attempts failed; evidence kept in $work_dir"
    fi

    end_ns="$(date +%s%N)"
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    if ! stream_elapsed_us="$(
        python3 - "$capture_log" "$frame_count" <<'PY'
import decimal
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
expected = int(sys.argv[2])
pattern = re.compile(
    r"^cap dqbuf:.*?\bseq:\s*(\d+).*?\bts:\s*([0-9]+\.[0-9]+)"
)
samples = []
for line in path.read_text(errors="replace").splitlines():
    match = pattern.search(line)
    if match:
        samples.append((int(match.group(1)), decimal.Decimal(match.group(2))))

if len(samples) != expected:
    raise SystemExit(
        f"V4L2 log contains {len(samples)}/{expected} frame timestamps"
    )
for previous, current in zip(samples, samples[1:]):
    if current[0] != previous[0] + 1:
        raise SystemExit(
            f"V4L2 sequence jumped from {previous[0]} to {current[0]}"
        )

elapsed = samples[-1][1] - samples[0][1]
if elapsed <= 0:
    raise SystemExit(f"invalid V4L2 frame span: {elapsed}")
print(int(elapsed * 1_000_000))
PY
    )"; then
        keep_work_dir=1
        fail "V4L2 timestamps or frame sequence are invalid; evidence kept in $work_dir"
    fi

    if [[ "$pixel_format" == "MJPG" ]] && ! python3 - "$capture" "$frame_count" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
expected = int(sys.argv[2])
data = path.read_bytes()
soi = b"\xff\xd8"
eoi = b"\xff\xd9"

if data.count(soi) != expected or data.count(eoi) != expected:
    raise SystemExit(
        f"JPEG marker mismatch: SOI={data.count(soi)}, "
        f"EOI={data.count(eoi)}, expected={expected}"
    )

offset = 0
for frame in range(1, expected + 1):
    if data[offset:offset + 2] != soi:
        raise SystemExit(
            f"frame {frame} does not start with SOI at byte {offset}"
        )
    end = data.find(eoi, offset + 2)
    if end < 0:
        raise SystemExit(f"frame {frame} has no EOI marker")
    offset = end + 2

if offset != len(data):
    raise SystemExit(
        f"{len(data) - offset} trailing byte(s) remain after frame {expected}"
    )
PY
    then
        keep_work_dir=1
        fail "MJPEG structure is corrupt; evidence kept in $work_dir"
    fi

    if [[ "$pixel_format" == "MJPG" ]]; then
        decoded_frames="$(
            nice -n 10 ffprobe -v error -threads 2 -f mjpeg -count_frames \
                -select_streams v:0 \
                -show_entries stream=nb_read_frames \
                -of default=noprint_wrappers=1:nokey=1 "$capture"
        )"
        [[ "$decoded_frames" == "$frame_count" ]] || {
            keep_work_dir=1
            fail "ffprobe decoded $decoded_frames/$frame_count frames; evidence kept in $work_dir"
        }

        if ! nice -n 10 ffmpeg -hide_banner -nostdin -v warning -xerror \
            -err_detect explode -threads 2 -f mjpeg -i "$capture" -map 0:v:0 \
            -f null - >"$decode_log" 2>&1; then
            keep_work_dir=1
            tail -60 "$decode_log" >&2
            fail "ffmpeg detected a damaged frame; evidence kept in $work_dir"
        fi
    else
        expected_bytes=$((width * height * 2 * frame_count))
        actual_bytes="$(stat -c %s "$capture")"
        if [[ "$actual_bytes" -ne "$expected_bytes" ]]; then
            keep_work_dir=1
            fail "YUYV capture has $actual_bytes/$expected_bytes bytes; evidence kept in $work_dir"
        fi
        if ! nice -n 10 ffmpeg -hide_banner -nostdin -v warning -xerror \
            -threads 2 -f rawvideo -pixel_format yuyv422 \
            -video_size "${width}x${height}" -framerate "$fps" \
            -i "$capture" -frames:v "$frame_count" -f null - \
            >"$decode_log" 2>&1; then
            keep_work_dir=1
            tail -60 "$decode_log" >&2
            fail "ffmpeg rejected the YUYV stream; evidence kept in $work_dir"
        fi
    fi

    measured_intervals=$((frame_count - 1))
    if ! python3 - "$measured_intervals" "$fps" "$stream_elapsed_us" \
        "$min_fps_ratio" "$max_fps_ratio" <<'PY'
import sys

frames = int(sys.argv[1])
requested = float(sys.argv[2])
elapsed_us = int(sys.argv[3])
minimum_ratio = float(sys.argv[4])
maximum_ratio = float(sys.argv[5])
actual = frames * 1_000_000.0 / elapsed_us
minimum = requested * minimum_ratio
maximum = requested * maximum_ratio
if not minimum <= actual <= maximum:
    raise SystemExit(
        f"actual rate {actual:.2f} fps is outside "
        f"{minimum:.2f}-{maximum:.2f} fps"
    )
PY
    then
        keep_work_dir=1
        fail "frame cadence is invalid; evidence kept in $work_dir"
    fi

    actual_fps="$(
        python3 - "$measured_intervals" "$stream_elapsed_us" <<'PY'
import sys
print(f"{int(sys.argv[1]) * 1_000_000.0 / int(sys.argv[2]):.2f}")
PY
    )"
    printf 'PASS: attempt %s/%s, %s intact frames in %.3fs wall / %.3fs stream (%s fps)\n' \
        "$attempt" "$attempts" "$frame_count" \
        "$(python3 -c "print($elapsed_ms / 1000)")" \
        "$(python3 -c "print($stream_elapsed_us / 1000000)")" "$actual_fps"
    sleep 2
done

printf 'PASS: frame integrity, decode, cadence and repeated starts are stable.\n'
