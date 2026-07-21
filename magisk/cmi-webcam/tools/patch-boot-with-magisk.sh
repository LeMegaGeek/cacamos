#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$repo_root/dist/magisk-test"
adb_bin="${ADB:-adb}"
magisk_api="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"

usage() {
    echo "Usage: $(basename "$0") /path/to/boot.img" >&2
}

boot_img="${1:-}"
if [[ -z "$boot_img" ]]; then
    usage
    exit 2
fi

boot_img="$(realpath "$boot_img")"
[[ -f "$boot_img" ]] || { echo "boot image not found: $boot_img" >&2; exit 1; }
command -v "$adb_bin" >/dev/null 2>&1 || { echo "adb not found" >&2; exit 127; }

mkdir -p "$work_dir"

read -r magisk_tag magisk_url magisk_name <<EOF_MAGISK
$(python3 - "$magisk_api" <<'PY'
import json, sys, urllib.request
with urllib.request.urlopen(sys.argv[1]) as r:
    data = json.load(r)
asset = next(a for a in data["assets"] if a["name"].startswith("Magisk-v") and a["name"].endswith(".apk"))
print(data["tag_name"], asset["browser_download_url"], asset["name"])
PY
)
EOF_MAGISK

apk="$work_dir/$magisk_name"
if [[ ! -f "$apk" ]]; then
    echo "Downloading $magisk_name ($magisk_tag)..."
    curl -L -o "$apk" "$magisk_url"
fi

patch_dir="$work_dir/patch-files"
rm -rf "$patch_dir"
mkdir -p "$patch_dir"
unzip -q -j "$apk" \
    assets/boot_patch.sh \
    assets/util_functions.sh \
    assets/stub.apk \
    lib/arm64-v8a/libbusybox.so \
    lib/arm64-v8a/libinit-ld.so \
    lib/arm64-v8a/libmagisk.so \
    lib/arm64-v8a/libmagiskboot.so \
    lib/arm64-v8a/libmagiskinit.so \
    -d "$patch_dir"

mv "$patch_dir/libbusybox.so" "$patch_dir/busybox"
mv "$patch_dir/libinit-ld.so" "$patch_dir/init-ld"
mv "$patch_dir/libmagisk.so" "$patch_dir/magisk"
mv "$patch_dir/libmagiskboot.so" "$patch_dir/magiskboot"
mv "$patch_dir/libmagiskinit.so" "$patch_dir/magiskinit"
chmod 755 "$patch_dir"/*

"$adb_bin" wait-for-device
device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
[[ "$device" == "cmi" ]] || { echo "Expected cmi, got ${device:-unset}" >&2; exit 1; }

remote="/data/local/tmp/cacam-magisk-patch"
"$adb_bin" shell "rm -rf '$remote' && mkdir -p '$remote'"
"$adb_bin" push "$patch_dir"/. "$remote"/ >/dev/null
"$adb_bin" push "$boot_img" "$remote/boot.img" >/dev/null

echo "Patching boot image on device with Magisk $magisk_tag..."
"$adb_bin" shell "cd '$remote' && BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false sh ./boot_patch.sh ./boot.img"

boot_base="$(basename "$boot_img")"
boot_base="${boot_base%.img}"
patched="$work_dir/${boot_base}-magisk-${magisk_tag}-patched.img"
"$adb_bin" pull "$remote/new-boot.img" "$patched" >/dev/null
sha256sum "$patched" > "$patched.sha256"
cat "$patched.sha256"
echo "Patched boot image: $patched"
