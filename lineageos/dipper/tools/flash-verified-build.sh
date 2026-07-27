#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB_BASE="${ADB:-adb}"
ADB_SERIAL="${ADB_SERIAL:-}"

if [[ -n "$ADB_SERIAL" ]]; then
    export ADB_SERIAL
fi

usage() {
    cat >&2 <<'DOC'
Usage:
  ./flash-verified-build.sh <lineage-root> [rom-zip]

Verify and install a local CaCam OS dipper OTA through ADB sideload.

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

lineage_root="${1:-}"
rom_path="${2:-}"

if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
require_cmd "$ADB_BASE"
if [[ -z "$rom_path" ]]; then
    canonical_ota="$lineage_root/out/target/product/dipper/lineage_dipper-ota.zip"
    if [[ -f "$canonical_ota" ]]; then
        rom_path="$canonical_ota"
    else
        rom_path="$(
            ls -t "$lineage_root"/out/target/product/dipper/lineage-22.2-*dipper.zip \
                2>/dev/null | head -n 1 || true
        )"
    fi
    if [[ -z "$rom_path" ]]; then
        fail "no matching ROM zip found under $lineage_root/out/target/product/dipper"
    fi
fi

if [[ ! -f "$rom_path" ]]; then
    fail "ROM zip not found: $rom_path"
fi

printf 'Running mandatory source and artifact gates...\n'
"$script_dir/verify-build-artifacts.sh" "$lineage_root" "$rom_path"

if [[ -n "$ADB_SERIAL" ]]; then
    state="$(adb_exec get-state 2>/dev/null | tr -d '\r' || true)"
    [[ "$state" == "sideload" ]] ||
        fail "ADB_SERIAL=$ADB_SERIAL is not in sideload mode (state: ${state:-not detected})"
else
    mapfile -t sideload_serials < <(
        "$ADB_BASE" devices 2>/dev/null | awk '$2 == "sideload" { print $1 }'
    )
    [[ "${#sideload_serials[@]}" -eq 1 ]] ||
        fail "expected exactly one ADB sideload device, found ${#sideload_serials[@]}"
    ADB_SERIAL="${sideload_serials[0]}"
    export ADB_SERIAL
fi

printf 'Installing OTA on %s through ADB sideload...\n' "$ADB_SERIAL"
adb_exec sideload "$rom_path"
printf 'OTA transfer completed. Confirm success in recovery, then reboot Android.\n'
