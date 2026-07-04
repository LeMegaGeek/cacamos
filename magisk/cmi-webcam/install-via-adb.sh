#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
module_version="$(awk -F= '$1=="version" {print $2}' "$script_dir/module.prop")"
zip_path="$repo_root/dist/CaCamOS-cmi-webcam-magisk-$module_version.zip"
remote_path="/data/local/tmp/CaCamOS-cmi-webcam-magisk-$module_version.zip"
adb_bin="${ADB:-adb}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

detect_su() {
    if "$adb_bin" shell su -c id >/dev/null 2>&1; then
        printf 'su'
        return 0
    fi
    if "$adb_bin" shell /debug_ramdisk/su -c id >/dev/null 2>&1; then
        printf '/debug_ramdisk/su'
        return 0
    fi
    return 1
}

root_shell() {
    local su_bin="$1"
    shift
    "$adb_bin" shell "$su_bin" -c "$*"
}

[[ -f "$zip_path" ]] || fail "module ZIP not found: $zip_path"
command -v "$adb_bin" >/dev/null 2>&1 || fail "adb not found"

"$adb_bin" wait-for-device

device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
[[ "$device" == "cmi" ]] || fail "expected cmi, got ${device:-unset}"

su_bin="$(detect_su || true)"
[[ -n "$su_bin" ]] || fail "root/Magisk su is not available on the connected cmi"

if root_shell "$su_bin" 'command -v magisk' >/dev/null 2>&1; then
    magisk_cmd="magisk"
elif root_shell "$su_bin" 'test -x /debug_ramdisk/magisk' >/dev/null 2>&1; then
    magisk_cmd="/debug_ramdisk/magisk"
else
    fail "Magisk command is not available through su"
fi

printf 'Pushing %s...\n' "$zip_path"
"$adb_bin" push "$zip_path" "$remote_path" >/dev/null

printf 'Installing Magisk module...\n'
root_shell "$su_bin" "$magisk_cmd --install-module '$remote_path'"

printf '\nInstalled. Reboot the phone, then run:\n'
printf '  %s/cacam-os/lineageos/cmi/tools/verify-webcam.sh\n' "$repo_root"
