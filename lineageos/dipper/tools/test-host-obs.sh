#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
report_dir="${1:-$(mktemp -d "${TMPDIR:-/tmp}/cacamos-obs.XXXXXX")}"
device="${V4L2_DEVICE:-}"
duration="${OBS_TEST_DURATION:-8}"
width="${WIDTH:-1280}"
height="${HEIGHT:-720}"
fps="${FPS:-30}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in ffprobe find fuser jq obs pgrep python3 taskset; do
    command -v "$command" >/dev/null 2>&1 || fail "missing command: $command"
done
[[ -x "$script_dir/find-cacamos-webcam.sh" ]] ||
    fail "missing executable: $script_dir/find-cacamos-webcam.sh"
for value_name in duration width height fps; do
    value="${!value_name}"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "$value_name must be a positive integer"
done
[[ -n "${DISPLAY:-}" ]] || fail "OBS qualification requires an X11 display"
if pgrep -x obs >/dev/null 2>&1; then
    fail "OBS is already running"
fi
if [[ -z "$device" ]]; then
    device="$("$script_dir/find-cacamos-webcam.sh")"
fi
[[ -e "$device" ]] || fail "capture node is missing: $device"
if fuser "$device" >/dev/null 2>&1; then
    fail "$device is already in use"
fi

work_dir="$report_dir/obs"
home_dir="$work_dir/home"
config_dir="$work_dir/config/obs-studio"
profile_name="CaCamOS Qualification"
collection_name="CaCamOS Qualification"
recording_dir="$work_dir/recordings"
mkdir -p \
    "$home_dir" \
    "$config_dir/basic/profiles/$profile_name" \
    "$config_dir/basic/scenes" \
    "$recording_dir"

printf '%s\n' \
    '[General]' \
    'Pre19Defaults=false' \
    'Pre21Defaults=false' \
    'FirstRun=true' \
    'EnableAutoUpdates=false' \
    '' \
    '[Basic]' \
    "Profile=$profile_name" \
    "ProfileDir=$profile_name" \
    "SceneCollection=$collection_name" \
    "SceneCollectionFile=$collection_name" \
    >"$config_dir/global.ini"

printf '%s\n' \
    '[General]' \
    "Name=$profile_name" \
    '' \
    '[Output]' \
    'Mode=Simple' \
    'FilenameFormatting=CaCamOS-OBS-%CCYY-%MM-%DD-%hh-%mm-%ss' \
    '' \
    '[SimpleOutput]' \
    "FilePath=$recording_dir" \
    'RecFormat2=mkv' \
    'RecQuality=Small' \
    'RecEncoder=x264' \
    'VBitrate=2500' \
    'ABitrate=96' \
    '' \
    '[Video]' \
    "BaseCX=$width" \
    "BaseCY=$height" \
    "OutputCX=$width" \
    "OutputCY=$height" \
    'FPSType=0' \
    "FPSCommon=$fps" \
    'ScaleType=bicubic' \
    'ColorFormat=NV12' \
    'ColorSpace=709' \
    'ColorRange=Partial' \
    >"$config_dir/basic/profiles/$profile_name/basic.ini"

source_uuid="7e51b17b-4dde-4fa8-8a52-caca05000001"
scene_uuid="7e51b17b-4dde-4fa8-8a52-caca05000002"
resolution=$((width * 4294967296 + height))
framerate=$((4294967296 + fps))
jq -n \
    --arg name "$collection_name" \
    --arg device "$device" \
    --arg source_uuid "$source_uuid" \
    --arg scene_uuid "$scene_uuid" \
    --argjson resolution "$resolution" \
    --argjson framerate "$framerate" \
    --argjson width "$width" \
    --argjson height "$height" \
    '{
      name: $name,
      groups: [],
      scene_order: [{name: "Webcam"}],
      current_scene: "Webcam",
      current_program_scene: "Webcam",
      canvases: [],
      current_transition: "Fade",
      transition_duration: 300,
      transitions: [],
      quick_transitions: [],
      saved_projectors: [],
      preview_locked: false,
      scaling_enabled: false,
      sources: [
        {
          prev_ver: 537001984,
          name: "CaCamOS Webcam",
          uuid: $source_uuid,
          id: "v4l2_input",
          versioned_id: "v4l2_input",
          settings: {
            device_id: $device,
            input: 0,
            pixelformat: 1196444237,
            resolution: $resolution,
            framerate: $framerate,
            auto_reset: true,
            timeout_frames: 5
          },
          mixers: 0,
          sync: 0,
          flags: 0,
          volume: 1.0,
          balance: 0.5,
          enabled: true,
          muted: false,
          hotkeys: {},
          deinterlace_mode: 0,
          deinterlace_field_order: 0,
          monitoring_type: 0,
          private_settings: {}
        },
        {
          prev_ver: 537001984,
          name: "Webcam",
          uuid: $scene_uuid,
          id: "scene",
          versioned_id: "scene",
          settings: {
            id_counter: 1,
            custom_size: false,
            items: [{
              name: "CaCamOS Webcam",
              source_uuid: $source_uuid,
              visible: true,
              locked: false,
              rot: 0.0,
              scale_ref: {x: $width, y: $height},
              align: 5,
              bounds_type: 0,
              bounds_align: 0,
              bounds_crop: false,
              crop_left: 0,
              crop_top: 0,
              crop_right: 0,
              crop_bottom: 0,
              id: 1,
              group_item_backup: false,
              pos: {x: 0.0, y: 0.0},
              scale: {x: 1.0, y: 1.0},
              bounds: {x: 0.0, y: 0.0},
              scale_filter: "disable",
              blend_method: "default",
              blend_type: "normal",
              show_transition: {duration: 0},
              hide_transition: {duration: 0},
              private_settings: {}
            }]
          },
          mixers: 0,
          sync: 0,
          flags: 0,
          volume: 1.0,
          balance: 0.5,
          enabled: true,
          muted: false,
          hotkeys: {},
          deinterlace_mode: 0,
          deinterlace_field_order: 0,
          monitoring_type: 0,
          private_settings: {}
        }
      ],
      modules: {},
      resolution: {x: $width, y: $height},
      migration_resolution: {x: $width, y: $height},
      version: 2
    }' >"$config_dir/basic/scenes/$collection_name.json"

obs_log="$work_dir/obs-console.log"
printf 'OBS native V4L2 recording (%ss)\n' "$duration"
HOME="$home_dir" XDG_CONFIG_HOME="$work_dir/config" \
    taskset -c 0-1 nice -n 10 obs \
        --multi \
        --only-bundled-plugins \
        --disable-missing-files-check \
        --collection "$collection_name" \
        --profile "$profile_name" \
        --scene Webcam \
        --minimize-to-tray \
        --startrecording \
        >"$obs_log" 2>&1 &
obs_pid="$!"

stop_obs() {
    if kill -0 "$obs_pid" 2>/dev/null; then
        kill -TERM "$obs_pid" 2>/dev/null || true
    fi
}
trap stop_obs EXIT INT TERM

recording_started=0
for ((attempt = 1; attempt <= 30; ++attempt)); do
    if rg -Fq '==== Recording Start' "$obs_log"; then
        recording_started=1
        break
    fi
    if ! kill -0 "$obs_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done
if [[ "$recording_started" -ne 1 ]]; then
    tail -120 "$obs_log" >&2
    fail "OBS did not start recording"
fi

sleep "$duration"
kill -TERM "$obs_pid" 2>/dev/null || true
for ((attempt = 1; attempt <= 40; ++attempt)); do
    if ! kill -0 "$obs_pid" 2>/dev/null; then
        break
    fi
    process_state="$(awk '{print $3}' "/proc/$obs_pid/stat" 2>/dev/null || true)"
    [[ "$process_state" == "Z" ]] && break
    sleep 0.25
done
process_state="$(awk '{print $3}' "/proc/$obs_pid/stat" 2>/dev/null || true)"
if kill -0 "$obs_pid" 2>/dev/null && [[ "$process_state" != "Z" ]]; then
    kill -KILL "$obs_pid" 2>/dev/null || true
    wait "$obs_pid" 2>/dev/null || true
    tail -120 "$obs_log" >&2
    fail "OBS did not stop cleanly"
fi

set +e
wait "$obs_pid"
obs_status="$?"
set -e
trap - EXIT INT TERM
if [[ "$obs_status" -ne 0 ]]; then
    tail -120 "$obs_log" >&2
    fail "OBS exited with status $obs_status"
fi
if rg -i \
    'select timed out|unable to start stream|failed to reset|failed to log status|error turning on stream|Stopped capture after 0 frames' \
    "$obs_log"; then
    tail -120 "$obs_log" >&2
    fail "OBS reported a stalled or failed V4L2 source"
fi

mapfile -t recordings < <(
    find "$recording_dir" -maxdepth 1 -type f -name '*.mkv' -print
)
[[ "${#recordings[@]}" -eq 1 ]] || {
    tail -120 "$obs_log" >&2
    fail "expected one OBS recording, found ${#recordings[@]}"
}
recording="${recordings[0]}"
ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=width,height,avg_frame_rate,nb_read_frames \
    -show_entries format=duration \
    -of json "$recording" >"$work_dir/ffprobe.json"

python3 - "$work_dir/ffprobe.json" "$width" "$height" "$fps" <<'PY'
import json
import pathlib
import sys

probe = json.loads(pathlib.Path(sys.argv[1]).read_text())
expected_width = int(sys.argv[2])
expected_height = int(sys.argv[3])
expected_fps = int(sys.argv[4])
streams = probe.get("streams", [])
if len(streams) != 1:
    raise SystemExit(f"OBS recording has {len(streams)} video streams")
stream = streams[0]
if stream.get("width") != expected_width or stream.get("height") != expected_height:
    raise SystemExit(
        f"OBS recorded {stream.get('width')}x{stream.get('height')}, "
        f"expected {expected_width}x{expected_height}"
    )
numerator, denominator = map(int, stream["avg_frame_rate"].split("/"))
actual_fps = numerator / denominator
if not expected_fps * 0.9 <= actual_fps <= expected_fps * 1.1:
    raise SystemExit(f"OBS recording rate is {actual_fps:.2f} fps")
frames = int(stream.get("nb_read_frames", 0))
if frames < expected_fps * 4:
    raise SystemExit(f"OBS recording contains only {frames} frames")
duration = float(probe.get("format", {}).get("duration", 0) or 0)
if duration <= 0:
    duration = frames / actual_fps
if duration < 4:
    raise SystemExit(f"OBS recording lasts only {duration:.3f} seconds")
print(
    f"OBS evidence: {frames} frames, {duration:.3f} seconds, "
    f"{actual_fps:.2f} fps"
)
PY

if rg -i 'bgobs|beau gosse obs' "$obs_log" "$config_dir/logs" 2>/dev/null; then
    fail "OBS loaded or referenced BGOBS during the native V4L2 qualification"
fi
printf 'PASS: stock OBS captured CaCamOS through its bundled V4L2 source.\n'
printf 'Evidence: %s\n' "$work_dir"
