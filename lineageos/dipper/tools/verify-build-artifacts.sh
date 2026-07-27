#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 <<'EOF'
Usage:
  verify-build-artifacts.sh <lineage-root> [ota-zip]

Checks the compiled DeviceAsWebcam APK, target-files staging tree, boot image,
OTA metadata and signatures. The OTA must be newer than every critical CaCamOS
source file.
EOF
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'OK: %s\n' "$*"
}

require_file() {
    [[ -f "$1" ]] || fail "missing file: $1"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

lineage_root="${1:-}"
ota_path="${2:-}"
if [[ -z "$lineage_root" ]]; then
    usage
    exit 2
fi

lineage_root="$(cd "$lineage_root" && pwd)"
product_out="$lineage_root/out/target/product/dipper"
host_bin="$lineage_root/out/host/linux-x86/bin"
target_files_dir="$product_out/obj/PACKAGING/target_files_intermediates/lineage_dipper-target_files"
apk="$product_out/system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk"
jni_lib="$product_out/system/lib64/libjni_deviceAsWebcam.so"
overlay_apk="$product_out/product/overlay/CaCamOsDeviceAsWebcamDipper.apk"
adbd_capex="$product_out/system/apex/com.android.adbd.capex"
kernel="$product_out/kernel"
kernel_vmlinux="$product_out/obj/KERNEL_OBJ/vmlinux"
boot_image="$product_out/boot.img"
staged_apk="$target_files_dir/SYSTEM/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk"
staged_jni_lib="$target_files_dir/SYSTEM/lib64/libjni_deviceAsWebcam.so"
staged_overlay_apk="$target_files_dir/PRODUCT/overlay/CaCamOsDeviceAsWebcamDipper.apk"
staged_adbd_capex="$target_files_dir/SYSTEM/apex/com.android.adbd.capex"
staged_kernel="$target_files_dir/BOOT/kernel"
staged_boot="$target_files_dir/IMAGES/boot.img"
staged_usb_init="$target_files_dir/VENDOR/etc/init/hw/init.qcom.usb.rc"
staged_device_init="$target_files_dir/VENDOR/etc/init/hw/init.target.rc"
platform_cert="$lineage_root/build/make/target/product/security/platform.x509.pem"
ota_cert="${OTA_CERTIFICATE:-$lineage_root/build/make/target/product/security/testkey.x509.pem}"
extract_ikconfig="$lineage_root/kernel/xiaomi/sdm845/scripts/extract-ikconfig"

if [[ -z "$ota_path" ]]; then
    ota_path="$product_out/lineage_dipper-ota.zip"
fi
ota_path="$(readlink -f "$ota_path")"

for command in python3 sha256sum unzip openssl cmp stat nm; do
    require_cmd "$command"
done
for tool in aapt2 apksigner check_ota_package_signature deapexer debugfs_static fsck.erofs; do
    require_file "$host_bin/$tool"
done
for file in \
    "$ota_path" \
    "$apk" \
    "$jni_lib" \
    "$overlay_apk" \
    "$adbd_capex" \
    "$kernel" \
    "$kernel_vmlinux" \
    "$boot_image" \
    "$staged_apk" \
    "$staged_jni_lib" \
    "$staged_overlay_apk" \
    "$staged_adbd_capex" \
    "$staged_kernel" \
    "$staged_boot" \
    "$staged_usb_init" \
    "$staged_device_init" \
    "$platform_cert" \
    "$ota_cert" \
    "$extract_ikconfig"; do
    require_file "$file"
done

"$script_dir/verify-patch-series.sh" --match-worktrees "$lineage_root"
"$script_dir/verify-source-tree.sh" "$lineage_root"

mapfile -t critical_relative_sources < <(
    sed -n 's|^diff --git a/[^ ]* b/||p' \
        "$script_dir"/../patches/*.patch | sort -u
)
[[ "${#critical_relative_sources[@]}" -gt 0 ]] ||
    fail "the patch series does not identify any critical source"
critical_sources=()
for relative_source in "${critical_relative_sources[@]}"; do
    critical_sources+=("$lineage_root/$relative_source")
done

ota_mtime="$(stat -c %Y "$ota_path")"
for file in "${critical_sources[@]}" "$apk" "$jni_lib" "$overlay_apk" "$adbd_capex" "$kernel" \
    "$kernel_vmlinux" \
    "$boot_image" "$staged_apk" "$staged_jni_lib" "$staged_overlay_apk" \
    "$staged_adbd_capex" "$staged_kernel" "$staged_boot" "$staged_usb_init" \
    "$staged_device_init"; do
    require_file "$file"
    if (( $(stat -c %Y "$file") > ota_mtime )); then
        fail "OTA is stale: $file is newer than $(basename "$ota_path")"
    fi
done
ok "OTA is newer than critical sources and compiled payloads"

cmp -s "$apk" "$staged_apk" ||
    fail "target-files contains a stale DeviceAsWebcam APK"
cmp -s "$jni_lib" "$staged_jni_lib" ||
    fail "target-files contains a stale DeviceAsWebcam JNI library"
cmp -s "$overlay_apk" "$staged_overlay_apk" ||
    fail "target-files contains a stale DeviceAsWebcam resource overlay"
cmp -s "$adbd_capex" "$staged_adbd_capex" ||
    fail "target-files contains a stale adbd APEX"
cmp -s "$kernel" "$staged_kernel" ||
    fail "target-files contains a stale kernel"
cmp -s "$lineage_root/device/xiaomi/dipper/init/init.target.rc" "$staged_device_init" ||
    fail "target-files contains a stale dipper init policy"

python3 - "$staged_usb_init" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
entries = []
for number, line in enumerate(text.splitlines(), 1):
    stripped = line.strip()
    if stripped.startswith("#") or "dwFrameInterval" not in stripped:
        continue
    entries.append((number, stripped.split("dwFrameInterval", 1)[1].strip()))
expected = r"333333\n666666\n"
if not entries or any(value != expected for _, value in entries):
    raise SystemExit(f"invalid staged UVC frame intervals: {entries}")

for profile in ("u/360p", "u1/360p"):
    base = f"/config/usb_gadget/g1/functions/uvc.0/streaming/uncompressed/{profile}"
    required = {
        f"write {base}/wWidth 640",
        f"write {base}/wHeight 360",
        f"write {base}/dwMinBitRate 55296000",
        f"write {base}/dwMaxBitRate 110592000",
        f"write {base}/dwMaxVideoFrameBufferSize 460800",
    }
    missing = sorted(entry for entry in required if entry not in text)
    if missing:
        raise SystemExit(f"staged {profile} has invalid raw-video descriptors: {missing}")

for prefix in ("mjpeg/m1", "mjpeg/m"):
    hd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/720p")
    sd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/360p")
    if hd >= sd:
        raise SystemExit(f"staged {prefix} does not default to 1280x720")

for header, mjpeg, raw in (("h1", "m1", "u1"), ("h", "m", "u")):
    mjpeg_link = text.index(
        f"streaming/mjpeg/{mjpeg} /config/usb_gadget/g1/functions/uvc.0/"
        f"streaming/header/{header}/{mjpeg}"
    )
    raw_link = text.index(
        f"streaming/uncompressed/{raw} /config/usb_gadget/g1/functions/uvc.0/"
        f"streaming/header/{header}/{raw}"
    )
    if mjpeg_link >= raw_link:
        raise SystemExit(f"staged {header} does not default to MJPEG")
PY
if grep -Fq "vendor.sys.usb.adb.disabled" "$staged_device_init"; then
    fail "staged dipper init still contains the obsolete USB-ADB property workaround"
fi
ok "target-files carries the current APK, JNI library, adbd, kernel and USB policies"

apk_verify_log="$(mktemp)"
apk_badging="$(mktemp)"
apk_permissions="$(mktemp)"
apk_xmltree="$(mktemp)"
metadata_file="$(mktemp)"
ota_entries="$(mktemp)"
kernel_config_file="$(mktemp)"
adbd_apex_dir="$(mktemp -d)"
trap 'rm -f "$apk_verify_log" "$apk_badging" "$apk_permissions" "$apk_xmltree" "$metadata_file" "$ota_entries" "$kernel_config_file"; rm -rf "$adbd_apex_dir"' EXIT

"$extract_ikconfig" "$kernel" >"$kernel_config_file"
for option in \
    CONFIG_MEDIA_SUPPORT=y \
    CONFIG_USB_GADGET=y \
    CONFIG_USB_CONFIGFS=y \
    CONFIG_USB_CONFIGFS_F_UVC=y; do
    grep -Fxq "$option" "$kernel_config_file" ||
        fail "compiled kernel is missing $option"
done
ok "compiled kernel contains the required UVC gadget configuration"
python3 - "$kernel" <<'PY'
import pathlib
import sys
import zlib

path = pathlib.Path(sys.argv[1])
compressed = path.read_bytes()
try:
    inflater = zlib.decompressobj(zlib.MAX_WBITS | 16)
    image = inflater.decompress(compressed) + inflater.flush()
except zlib.error as error:
    raise SystemExit(f"cannot decompress compiled kernel: {error}")
if not inflater.eof:
    raise SystemExit("compiled kernel gzip stream is incomplete")
if b"encoded request queue temporarily empty" not in image:
    raise SystemExit("compiled kernel lacks the recoverable UVC back-pressure path")
if b"aborted incomplete frame" in image:
    raise SystemExit("compiled kernel still contains the freeze-inducing UVC frame abort")
PY
ok "compiled kernel contains the non-aborting isochronous request flow"
nm "$kernel_vmlinux" |
    awk '$3 == "uvcg_complete_buffer" { found = 1 } END { exit !found }' ||
    fail "compiled kernel lacks delayed V4L2 completion at USB request completion"
ok "compiled kernel retains each V4L2 buffer until its final USB request completes"

"$host_bin/deapexer" \
    --debugfs_path "$host_bin/debugfs_static" \
    --fsckerofs_path "$host_bin/fsck.erofs" \
    decompress \
    --input "$staged_adbd_capex" \
    --output "$adbd_apex_dir/com.android.adbd.apex"
"$host_bin/deapexer" \
    --debugfs_path "$host_bin/debugfs_static" \
    --fsckerofs_path "$host_bin/fsck.erofs" \
    extract \
    "$adbd_apex_dir/com.android.adbd.apex" \
    "$adbd_apex_dir/extracted"
require_file "$adbd_apex_dir/extracted/bin/adbd"
grep -aFq "USB FunctionFS transport disabled by CaCamOS UVC-only policy" \
    "$adbd_apex_dir/extracted/bin/adbd" ||
    fail "compiled adbd does not suppress its USB transport in CaCamOS"
ok "compiled adbd keeps the cable UVC-only while retaining network transports"

"$host_bin/apksigner" verify --verbose --print-certs "$apk" >"$apk_verify_log"
grep -Fq "Verifies" "$apk_verify_log" || fail "DeviceAsWebcam APK signature is invalid"
python3 - "$apk" <<'PY'
import pathlib
import sys
import zipfile

path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(path) as archive:
    dex = b"".join(
        archive.read(name)
        for name in archive.namelist()
        if name.startswith("classes") and name.endswith(".dex")
    )
for marker in (
    b"shouldQueueWebcamFrameLocked",
    b"ImageReader returned an image without a hardware buffer",
):
    if marker not in dex:
        raise SystemExit(f"compiled DeviceAsWebcam APK lacks {marker.decode()}")
PY
ok "compiled DeviceAsWebcam APK contains negotiated FPS pacing"

expected_platform_digest="$(
    openssl x509 -in "$platform_cert" -outform DER | sha256sum | awk '{print $1}'
)"
actual_apk_digest="$(
    awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print $2; exit}' "$apk_verify_log"
)"
[[ "$actual_apk_digest" == "$expected_platform_digest" ]] ||
    fail "DeviceAsWebcam APK is not signed with the expected platform certificate"

"$host_bin/aapt2" dump badging "$apk" >"$apk_badging"
"$host_bin/aapt2" dump permissions "$apk" >"$apk_permissions"
"$host_bin/aapt2" dump xmltree "$apk" --file AndroidManifest.xml >"$apk_xmltree"

grep -Fq "package: name='com.android.DeviceAsWebcam'" "$apk_badging" ||
    fail "compiled APK package name is incorrect"
python3 - "$apk_permissions" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
requested = set(re.findall(r"^uses-permission: name='([^']+)'$", text, re.MULTILINE))
expected = {
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.CAMERA",
    "android.permission.FOREGROUND_SERVICE_CAMERA",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.POST_NOTIFICATIONS",
    "com.android.DeviceAsWebcam.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
}
if requested != expected:
    raise SystemExit(
        "compiled APK permissions differ from the audited set: "
        f"found={sorted(requested)}, expected={sorted(expected)}"
    )
PY
for marker in \
    'android:sharedUserId(0x0101000b)="android.uid.system"' \
    'coreApp=true' \
    'android.intent.action.BOOT_COMPLETED' \
    'android.intent.action.LOCKED_BOOT_COMPLETED' \
    'com.android.DeviceAsWebcam.action.PREPARE_UVC' \
    'android.permission.MANAGE_USB'; do
    grep -Fq "$marker" "$apk_xmltree" ||
        fail "compiled APK manifest is missing: $marker"
done
direct_boot_count="$(grep -Fc 'directBootAware(0x01010505)=true' "$apk_xmltree")"
(( direct_boot_count >= 3 )) ||
    fail "receiver, activity and service are not all direct-boot aware"
grep -Fq 'foregroundServiceType(0x01010599)=0x00000040' "$apk_xmltree" ||
    fail "compiled service is not declared as a camera foreground service"
ok "platform-signed APK and minimal compiled permission set"

unzip -tq "$ota_path"
unzip -p "$ota_path" META-INF/com/android/metadata >"$metadata_file"
unzip -Z1 "$ota_path" >"$ota_entries"
grep -Fxq "ota-type=BLOCK" "$metadata_file" ||
    fail "OTA is not a block OTA"
grep -Fxq "pre-device=dipper" "$metadata_file" ||
    fail "OTA is not restricted to dipper"
grep -Eq '^post-sdk-level=35$' "$metadata_file" ||
    fail "OTA SDK level is not 35"

for entry in \
    boot.img \
    recovery.img \
    system.new.dat.br \
    system_ext.new.dat.br \
    product.new.dat.br \
    vendor.new.dat.br \
    META-INF/com/android/otacert; do
    grep -Fxq "$entry" "$ota_entries" ||
        fail "OTA payload is missing $entry"
done

staged_boot_hash="$(sha256sum "$staged_boot" | awk '{print $1}')"
ota_boot_hash="$(unzip -p "$ota_path" boot.img | sha256sum | awk '{print $1}')"
[[ "$staged_boot_hash" == "$ota_boot_hash" ]] ||
    fail "OTA boot.img does not match the verified target-files boot image"

"$host_bin/check_ota_package_signature" "$ota_cert" "$ota_path"
ok "OTA archive, device metadata, boot payload and whole-package signature"

sha256sum "$ota_path"
printf '\nPASS: build artifacts are eligible for ADB sideload.\n'
