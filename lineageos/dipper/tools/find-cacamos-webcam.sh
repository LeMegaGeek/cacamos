#!/usr/bin/env bash
set -euo pipefail

vendor_id="${CACAMOS_USB_VENDOR_ID:-18d1}"
product_id="${CACAMOS_USB_PRODUCT_ID:-4eef}"
usb_serial="${CACAMOS_USB_SERIAL:-}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

for command in grep readlink udevadm v4l2-ctl; do
    command -v "$command" >/dev/null 2>&1 ||
        fail "missing command: $command"
done

shopt -s nullglob
video_nodes=(/dev/video*)
shopt -u nullglob

candidates=()
for node in "${video_nodes[@]}"; do
    properties="$(udevadm info --query=property --name="$node" 2>/dev/null || true)"
    grep -Fxq "ID_VENDOR_ID=$vendor_id" <<<"$properties" || continue
    grep -Fxq "ID_MODEL_ID=$product_id" <<<"$properties" || continue
    if [[ -n "$usb_serial" ]]; then
        grep -Fxq "ID_SERIAL_SHORT=$usb_serial" <<<"$properties" || continue
    fi
    grep -Eq '^ID_V4L_CAPABILITIES=.*:capture:' <<<"$properties" || continue

    info="$(v4l2-ctl --device="$node" --all 2>/dev/null || true)"
    grep -Eq 'Driver name[[:space:]]*: uvcvideo' <<<"$info" || continue
    grep -Eq 'Device Caps[[:space:]]*: 0x[0-9a-fA-F]*1$|Video Capture' <<<"$info" ||
        continue
    candidates+=("$(readlink -f "$node")")
done

if [[ "${#candidates[@]}" -ne 1 ]]; then
    identity="${vendor_id}:${product_id}"
    [[ -z "$usb_serial" ]] || identity+=" serial $usb_serial"
    fail "expected exactly one CaCamOS USB capture node for $identity, found ${#candidates[@]}"
fi

printf '%s\n' "${candidates[0]}"
