#!/usr/bin/env bash
set -euo pipefail

ADB_BASE="${ADB:-adb}"
ADB_SERIAL="${ADB_SERIAL:-}"

if [[ -n "$ADB_SERIAL" ]]; then
    export ADB_SERIAL
fi

usage() {
    cat >&2 <<'DOC'
Usage:
  ./flash-verified-build.sh <lineage-root> [rom-zip]

Flash a local CaCam OS dipper ROM zip and run the runtime verification script.

Arguments:
  <lineage-root>  LineageOS workspace root used for this build.
  [rom-zip]       Optional path to lineage-22.2-*dipper.zip.
                  If omitted, the newest matching zip from
                  <lineage-root>/out/target/product/dipper is used.
DOC
}

fail() {
    printf 'ERROR: %s\n' "$*"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

adb_exec() {
    local cmd=("$ADB_BASE")
    if [[ -n "$ADB_SERIAL" ]]; then
        cmd+=(-s "$ADB_SERIAL")
    fi
    "${cmd[@]}" "$@"
}

set_adb_target() {
    local forced_serial="${1:-}"
    if [[ -n "$forced_serial" ]]; then
        if "$ADB_BASE" -s "$forced_serial" get-state >/dev/null 2>&1; then
            ADB_SERIAL="$forced_serial"
            export ADB_SERIAL
            return 0
        fi
        ADB_SERIAL=""
        unset ADB_SERIAL
    fi

    local adb_state_line
    adb_state_line="$(adb_exec devices 2>/dev/null | awk '$2 == "device" || $2 == "sideload" || $2 == "recovery" { print $1" "$2; exit }' || true)"
    if [[ -n "$adb_state_line" ]]; then
        read -r ADB_SERIAL _ <<< "$adb_state_line"
        export ADB_SERIAL
        return 0
    fi

    ADB_SERIAL=""
    unset ADB_SERIAL
    return 1
}

get_adb_state() {
    local serial_guess="${1:-}"
    set_adb_target "$serial_guess" || return 1
    adb_exec get-state 2>/dev/null | tr -d '\r' || true
}

wait_for_fastboot() {
    local timeout_s="$1"
    local i
    local serial=""

    for i in $(seq 1 "$timeout_s"); do
        serial="$(fastboot devices | awk '$2 == "fastboot" { print $1; exit }')"
        if [[ -n "$serial" ]]; then
            echo "$serial"
            return 0
        fi
        sleep 1
    done

    return 1
}

wait_for_adb_device() {
    local timeout_s="$1"
    local i

    for i in $(seq 1 "$timeout_s"); do
        if set_adb_target 2>/dev/null; then
            adb_exec get-state >/dev/null 2>&1 && adb_exec wait-for-device >/dev/null
            return 0
        fi
        if adb_exec get-state >/dev/null 2>&1; then
            adb_exec wait-for-device >/dev/null
            return 0
        fi
        sleep 1
    done

    return 1
}

sideload_rom() {
    local target_rom="$1"

    printf 'Device is in sideload mode. Flashing ZIP from recovery...\n'
    if ! adb_exec sideload "$target_rom"; then
        fail "adb sideload failed"
    fi
}

flash_with_fastboot() {
    local target_rom="$1"
    local target_serial="$2"

    printf 'Fastboot device ready: %s\n' "$target_serial"
    fastboot -s "$target_serial" update "$target_rom"
    fastboot -s "$target_serial" reboot
}

verify_device() {
    local verify_script=$1
    local active_serial

    if ! wait_for_adb_device 180; then
        fail "ADB device did not return within 180s"
    fi

    active_serial="$(adb_exec get-serialno 2>/dev/null | tr -d '\r' || true)"
    if [[ -z "$active_serial" ]]; then
        active_serial="$("$ADB_BASE" devices | awk '$2 == "device" { print $1; exit }')"
    fi

    if [[ -n "$active_serial" ]]; then
        ADB_SERIAL="$active_serial"
        export ADB_SERIAL
    else
        # Keep the environment clean when no serial can be inferred.
        ADB_SERIAL=""
        unset ADB_SERIAL
    fi

    adb_exec shell getprop ro.product.device >/dev/null

    echo "Running post-flash verification on ${active_serial:-<default>}"
    "$verify_script"
}

lineage_root="${1:-}"
rom_path="${2:-}"

if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
require_cmd "$ADB_BASE"
require_cmd fastboot

if [[ -z "$rom_path" ]]; then
    rom_path="$(ls -t "$lineage_root"/out/target/product/dipper/lineage-22.2-*dipper.zip 2>/dev/null | head -n 1 || true)"
    if [[ -z "$rom_path" ]]; then
        fail "no matching ROM zip found under $lineage_root/out/target/product/dipper"
    fi
fi

if [[ ! -f "$rom_path" ]]; then
    fail "ROM zip not found: $rom_path"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verify_script="$script_dir/verify-webcam.sh"
[[ -x "$verify_script" ]] || fail "verify script is missing: $verify_script"

echo "Using LineageOS workspace: $lineage_root"
echo "Flashing ROM: $rom_path"

if ! set_adb_target "${ADB_SERIAL:-}"; then
    state=""
else
    state="$(get_adb_state "$ADB_SERIAL")"
fi

case "$state" in
    sideload)
        sideload_rom "$rom_path"
        verify_device "$verify_script"
        ;;
    device)
        echo "Phone is in adb mode. Rebooting to fastboot..."
        adb_exec reboot bootloader
        ;;
    "")
        echo "No ADB state available; waiting for fastboot directly."
        ;;
    *)
        printf "ADB reports state '%s'. Not forcing reboot into fastboot again.\n" "$state"
        ;;
esac

if [[ "$state" != "sideload" ]]; then
    echo "Waiting up to 180 seconds for fastboot"
    if ! target_serial="$(wait_for_fastboot 180)"; then
        if set_adb_target; then
            state="$(get_adb_state "$ADB_SERIAL")"
        else
            state=""
        fi
        if [[ -n "$state" ]]; then
            if [[ -n "$ADB_SERIAL" ]]; then
                fail "fastboot device not detected yet (still in adb state '$state' for '$ADB_SERIAL')."
            fi
            fail "fastboot device not detected yet (still in adb state '$state')."
        fi

        fail "No ADB/fastboot connection detected. If the phone rebooted, manually boot into fastboot (Vol- + Power) and rerun."
    fi

    flash_with_fastboot "$rom_path" "$target_serial"
    verify_device "$verify_script"
fi

echo "Done. If the device still does not appear as a webcam in host software,"
echo "plug it on the PC again and run:"
echo "  v4l2-ctl --list-devices"
