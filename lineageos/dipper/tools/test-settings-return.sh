#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../.." && pwd)"
adb_bin="${ADB:-adb}"
adb_serial="${ADB_SERIAL:-}"
report_dir="${1:-$project_root/dist/cacam-os-settings-return}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in "$adb_bin" python3; do
    command -v "$command" >/dev/null 2>&1 ||
        fail "missing command: $command"
done

if [[ -z "$adb_serial" ]]; then
    mapfile -t serials < <(
        "$adb_bin" devices 2>/dev/null | awk '$2 == "device" { print $1 }'
    )
    [[ "${#serials[@]}" -eq 1 ]] ||
        fail "expected exactly one running ADB device"
    adb_serial="${serials[0]}"
fi
adb_cmd=("$adb_bin" -s "$adb_serial")

adb_shell() {
    "${adb_cmd[@]}" shell "$@" 2>/dev/null | tr -d '\r'
}

mkdir -p "$report_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
report="$report_dir/${timestamp}-settings-return.txt"
ui_dump="$report_dir/${timestamp}-settings-ui.xml"
exec > >(tee "$report") 2>&1

printf 'CaCamOS Settings return qualification\n'
printf 'date=%s\n' "$(date -Is)"
printf 'adb_target=%s\n' "$adb_serial"

boot_id_before="$(adb_shell cat /proc/sys/kernel/random/boot_id)"
webcam_pid_before="$(adb_shell pidof com.android.DeviceAsWebcam)"
[[ -n "$webcam_pid_before" ]] || fail "DeviceAsWebcam is not running"

"${adb_cmd[@]}" shell am start -W -a android.settings.SETTINGS >/dev/null

settings_resumed=0
for _ in $(seq 1 20); do
    resumed="$(adb_shell dumpsys activity activities |
        grep -m1 'mResumedActivity' || true)"
    if [[ "$resumed" == *"com.android.settings"* ]]; then
        settings_resumed=1
        break
    fi
    sleep 0.25
done
[[ "$settings_resumed" -eq 1 ]] || fail "Settings did not become the resumed activity"

tap_coordinates=""
for _ in $(seq 1 30); do
    "${adb_cmd[@]}" shell uiautomator dump --compressed \
        /data/local/tmp/cacamos-settings.xml >/dev/null 2>&1 || true
    "${adb_cmd[@]}" exec-out cat /data/local/tmp/cacamos-settings.xml \
        >"$ui_dump" 2>/dev/null || true
    tap_coordinates="$(
        python3 - "$ui_dump" <<'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

path = pathlib.Path(sys.argv[1])
if not path.is_file() or path.stat().st_size == 0:
    raise SystemExit
try:
    root = ET.parse(path).getroot()
except ET.ParseError:
    raise SystemExit

labels = {"Retour à la webcam", "Return to webcam"}
for node in root.iter("node"):
    if node.get("text") not in labels:
        continue
    match = re.fullmatch(
        r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if match is None:
        raise SystemExit
    left, top, right, bottom = map(int, match.groups())
    print(f"{(left + right) // 2} {(top + bottom) // 2} {node.get('text')}")
    break
PY
    )"
    [[ -n "$tap_coordinates" ]] && break
    sleep 0.5
done
[[ -n "$tap_coordinates" ]] ||
    fail "Settings does not display the CaCamOS webcam return action"

read -r tap_x tap_y return_label <<<"$tap_coordinates"
printf 'return_label=%s\n' "$return_label"
printf 'tap=%s,%s\n' "$tap_x" "$tap_y"
"${adb_cmd[@]}" shell input tap "$tap_x" "$tap_y"

preview_resumed=0
for _ in $(seq 1 40); do
    resumed="$(adb_shell dumpsys activity activities |
        grep -m1 'mResumedActivity' || true)"
    if [[ "$resumed" == *"com.android.DeviceAsWebcam/"* &&
        "$resumed" == *"DeviceAsWebcamPreview"* ]]; then
        preview_resumed=1
        break
    fi
    sleep 0.25
done
[[ "$preview_resumed" -eq 1 ]] ||
    fail "the Settings action did not return to the webcam preview"

boot_id_after="$(adb_shell cat /proc/sys/kernel/random/boot_id)"
webcam_pid_after="$(adb_shell pidof com.android.DeviceAsWebcam)"
[[ "$boot_id_after" == "$boot_id_before" ]] ||
    fail "the phone restarted during the Settings return test"
[[ "$webcam_pid_after" == "$webcam_pid_before" ]] ||
    fail "DeviceAsWebcam restarted during the Settings return test"

printf 'webcam_pid=%s\n' "$webcam_pid_after"
printf 'PASS: Settings exposes one-tap return to the running webcam preview.\n'
printf 'Evidence: %s\n' "$report_dir"
