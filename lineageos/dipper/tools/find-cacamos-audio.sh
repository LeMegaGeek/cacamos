#!/usr/bin/env bash
set -euo pipefail

vendor_id="${CACAMOS_USB_VENDOR_ID:-18d1}"
product_id="${CACAMOS_USB_PRODUCT_ID:-4eef}"
usb_serial="${CACAMOS_USB_SERIAL:-}"
output_format="${1:-human}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ "$output_format" == "human" || "$output_format" == "--tsv" ]] ||
    fail "usage: find-cacamos-audio.sh [--tsv]"

for command in basename cat dirname readlink; do
    command -v "$command" >/dev/null 2>&1 ||
        fail "missing command: $command"
done

find_usb_parent() {
    local path="$1"

    while [[ "$path" != "/" ]]; do
        if [[ -r "$path/idVendor" && -r "$path/idProduct" ]] &&
            [[ "$(tr '[:upper:]' '[:lower:]' < "$path/idVendor")" == "$vendor_id" ]] &&
            [[ "$(tr '[:upper:]' '[:lower:]' < "$path/idProduct")" == "$product_id" ]]; then
            if [[ -n "$usb_serial" ]] &&
                [[ ! -r "$path/serial" || "$(tr -d '\r\n' < "$path/serial")" != "$usb_serial" ]]; then
                return 1
            fi
            printf '%s\n' "$path"
            return 0
        fi
        path="$(dirname "$path")"
    done
    return 1
}

shopt -s nullglob
sound_cards=(/sys/class/sound/card[0-9]*)
shopt -u nullglob

matches=()
for card_path in "${sound_cards[@]}"; do
    card_name="$(basename "$card_path")"
    card_index="${card_name#card}"
    [[ "$card_index" =~ ^[0-9]+$ ]] || continue
    device_path="$(readlink -f "$card_path/device")"
    usb_path="$(find_usb_parent "$device_path" || true)"
    [[ -n "$usb_path" ]] || continue
    matches+=("$card_index"$'\t'"$usb_path")
done

identity="${vendor_id}:${product_id}"
[[ -z "$usb_serial" ]] || identity+=" serial $usb_serial"
[[ "${#matches[@]}" -eq 1 ]] ||
    fail "expected exactly one CaCamOS USB audio card for $identity, found ${#matches[@]}"

IFS=$'\t' read -r card_index usb_path <<<"${matches[0]}"
card_id="$(tr -d '\r\n' < "/proc/asound/card${card_index}/id")"

shopt -s nullglob
capture_nodes=(/dev/snd/pcmC"${card_index}"D*c)
playback_nodes=(/dev/snd/pcmC"${card_index}"D*p)
shopt -u nullglob

[[ "${#capture_nodes[@]}" -eq 1 ]] ||
    fail "expected one CaCamOS host microphone PCM, found ${#capture_nodes[@]}"
[[ "${#playback_nodes[@]}" -eq 1 ]] ||
    fail "expected one CaCamOS host speaker PCM, found ${#playback_nodes[@]}"

capture_name="$(basename "${capture_nodes[0]}")"
playback_name="$(basename "${playback_nodes[0]}")"
[[ "$capture_name" =~ ^pcmC[0-9]+D([0-9]+)c$ ]] ||
    fail "cannot parse capture PCM: $capture_name"
capture_device="${BASH_REMATCH[1]}"
[[ "$playback_name" =~ ^pcmC[0-9]+D([0-9]+)p$ ]] ||
    fail "cannot parse playback PCM: $playback_name"
playback_device="${BASH_REMATCH[1]}"

if [[ "$output_format" == "--tsv" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$card_index" "$capture_device" "$playback_device" "$card_id" "$usb_path"
else
    printf 'usb_identity=%s:%s\n' "$vendor_id" "$product_id"
    printf 'usb_path=%s\n' "$usb_path"
    printf 'alsa_card_index=%s\n' "$card_index"
    printf 'alsa_card_id=%s\n' "$card_id"
    printf 'microphone=plughw:%s,%s\n' "$card_index" "$capture_device"
    printf 'speakers=plughw:%s,%s\n' "$card_index" "$playback_device"
fi
