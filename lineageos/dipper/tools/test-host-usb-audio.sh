#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
duration="${AUDIO_CAPTURE_DURATION:-6}"
tone_duration="${AUDIO_TONE_DURATION:-3}"
tone_frequency="${AUDIO_TONE_FREQUENCY:-997}"
min_rms="${AUDIO_MIN_RMS:-64}"
min_tone_ratio="${AUDIO_MIN_TONE_RATIO:-0.08}"
video_device="${V4L2_DEVICE:-}"
video_width="${VIDEO_WIDTH:-1280}"
video_height="${VIDEO_HEIGHT:-720}"
video_fps="${VIDEO_FPS:-30}"
output_dir="${1:-$(pwd)/cacamos-audio-test}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for value in "$duration" "$tone_duration" "$tone_frequency" "$min_rms" \
    "$video_width" "$video_height" "$video_fps"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "audio durations, frequency and minimum RMS must be positive integers"
done
python3 - "$min_tone_ratio" <<'PY'
import sys

value = float(sys.argv[1])
if not 0.0 < value < 1.0:
    raise SystemExit("AUDIO_MIN_TONE_RATIO must be between 0 and 1")
PY

for command in aplay arecord python3; do
    command -v "$command" >/dev/null 2>&1 ||
        fail "missing command: $command"
done
[[ -x "$script_dir/find-cacamos-audio.sh" ]] ||
    fail "missing executable: $script_dir/find-cacamos-audio.sh"
if [[ -n "$video_device" ]]; then
    command -v v4l2-ctl >/dev/null 2>&1 ||
        fail "missing command: v4l2-ctl"
    [[ -c "$video_device" ]] || fail "invalid V4L2 device: $video_device"
fi

mkdir -p "$output_dir"
IFS=$'\t' read -r card_index capture_device playback_device card_id usb_path < <(
    "$script_dir/find-cacamos-audio.sh" --tsv
)
capture_pcm="plughw:${card_index},${capture_device}"
playback_pcm="plughw:${card_index},${playback_device}"
recording="$output_dir/cacamos-roundtrip.wav"
tone="$output_dir/cacamos-test-tone.wav"
audio_log="$output_dir/audio-commands.log"
video_log="$output_dir/video-stream.log"

printf 'usb_path=%s\n' "$usb_path"
printf 'alsa_card=%s (%s)\n' "$card_index" "$card_id"
printf 'microphone=%s\n' "$capture_pcm"
printf 'speakers=%s\n' "$playback_pcm"

python3 - "$tone" "$tone_frequency" "$tone_duration" <<'PY'
import math
import struct
import sys
import wave

path, frequency, duration = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
rate = 48_000
amplitude = 8_000
frames = bytearray()
for index in range(round(rate * duration)):
    fade = min(1.0, index / 2400, (rate * duration - index) / 2400)
    sample = round(amplitude * fade * math.sin(2.0 * math.pi * frequency * index / rate))
    frames.extend(struct.pack("<hh", sample, sample))
with wave.open(path, "wb") as stream:
    stream.setnchannels(2)
    stream.setsampwidth(2)
    stream.setframerate(rate)
    stream.writeframes(frames)
PY

video_pid=""
capture_pid=""
cleanup() {
    local pid

    for pid in "$capture_pid" "$video_pid"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT INT TERM

if [[ -n "$video_device" ]]; then
    frame_count=$((duration * video_fps))
    v4l2-ctl --device="$video_device" \
        --set-fmt-video=width="$video_width",height="$video_height",pixelformat=MJPG \
        --set-parm="$video_fps" \
        --stream-mmap=4 \
        --stream-count="$frame_count" \
        --stream-to=/dev/null >"$video_log" 2>&1 &
    video_pid=$!
fi

arecord --quiet --device="$capture_pcm" --file-type=wav \
    --format=S16_LE --rate=48000 --channels=1 \
    --duration="$duration" "$recording" >"$audio_log" 2>&1 &
capture_pid=$!
sleep 1
aplay --quiet --device="$playback_pcm" "$tone" >>"$audio_log" 2>&1 ||
    fail "the host could not play PCM through the CaCamOS speakers endpoint"

if ! wait "$capture_pid"; then
    capture_pid=""
    fail "the host could not record PCM from the CaCamOS microphone endpoint"
fi
capture_pid=""

if [[ -n "$video_pid" ]]; then
    if ! wait "$video_pid"; then
        video_pid=""
        fail "UVC streaming failed while USB audio was active"
    fi
    video_pid=""
fi

python3 - "$recording" "$tone_frequency" "$min_rms" "$min_tone_ratio" \
    "$tone_duration" "$duration" <<'PY'
import array
import math
import sys
import wave

path = sys.argv[1]
frequency = float(sys.argv[2])
minimum_rms = float(sys.argv[3])
minimum_ratio = float(sys.argv[4])
tone_duration = float(sys.argv[5])
capture_duration = float(sys.argv[6])

with wave.open(path, "rb") as stream:
    channels = stream.getnchannels()
    width = stream.getsampwidth()
    rate = stream.getframerate()
    frames = stream.getnframes()
    samples = array.array("h", stream.readframes(frames))

if channels != 1 or width != 2 or rate != 48_000:
    raise SystemExit(
        f"FAIL: unexpected microphone format: channels={channels}, width={width}, rate={rate}"
    )
if sys.byteorder != "little":
    samples.byteswap()

expected_frames = round(rate * capture_duration)
if frames != expected_frames:
    raise SystemExit(
        f"FAIL: incomplete microphone capture: frames={frames}, expected={expected_frames}"
    )

start = min(len(samples), rate)
end = min(len(samples), start + round(rate * tone_duration))
window = samples[start:end]
if not window:
    raise SystemExit("FAIL: microphone capture contains no test window")

sum_squares = sum(sample * sample for sample in window)
rms = math.sqrt(sum_squares / len(window))
peak = max(abs(sample) for sample in window)
omega = 2.0 * math.pi * frequency / rate
cosine = sum(sample * math.cos(omega * index) for index, sample in enumerate(window))
sine = sum(sample * math.sin(omega * index) for index, sample in enumerate(window))
tone_rms = math.sqrt(2.0) * math.hypot(cosine, sine) / len(window)
tone_ratio = tone_rms / rms if rms else 0.0

print(f"microphone_frames={frames}")
print(f"microphone_rms={rms:.2f}")
print(f"microphone_peak={peak}")
print(f"tone_rms={tone_rms:.2f}")
print(f"tone_ratio={tone_ratio:.4f}")

if rms < minimum_rms:
    raise SystemExit(
        f"FAIL: microphone signal RMS {rms:.2f} is below {minimum_rms:.2f}"
    )
if tone_ratio < minimum_ratio:
    raise SystemExit(
        f"FAIL: {frequency:.0f} Hz acoustic return ratio {tone_ratio:.4f} "
        f"is below {minimum_ratio:.4f}"
    )
PY

printf 'PASS: standard USB microphone and speakers completed a 48 kHz acoustic round trip'
if [[ -n "$video_device" ]]; then
    printf ' while UVC streamed at %sx%s@%s' "$video_width" "$video_height" "$video_fps"
fi
printf '.\n'
