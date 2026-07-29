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
staged_settings_apk="$target_files_dir/SYSTEM_EXT/priv-app/Settings/Settings.apk"
staged_settings_provider_overlay="$target_files_dir/VENDOR/overlay/SettingsProvider__lineage_dipper__auto_generated_rro_vendor.apk"
staged_system_build_prop="$target_files_dir/SYSTEM/build.prop"
staged_product_build_prop="$target_files_dir/PRODUCT/etc/build.prop"
bootanimation="$lineage_root/device/xiaomi/dipper/bootanimation/bootanimation.zip"
staged_bootanimation="$target_files_dir/PRODUCT/media/bootanimation.zip"
staged_kernel="$target_files_dir/BOOT/kernel"
staged_boot="$target_files_dir/IMAGES/boot.img"
staged_recovery="$target_files_dir/RECOVERY/RAMDISK/system/bin/recovery"
staged_recovery_prop="$target_files_dir/RECOVERY/RAMDISK/prop.default"
staged_usb_init="$target_files_dir/VENDOR/etc/init/hw/init.qcom.usb.rc"
staged_device_init="$target_files_dir/VENDOR/etc/init/hw/init.target.rc"
boot_probe="$lineage_root/device/xiaomi/dipper/init/cacamos_boot_probe.sh"
staged_boot_probe="$target_files_dir/SYSTEM/bin/cacamos_boot_probe.sh"
privapp_permissions="$lineage_root/device/xiaomi/dipper/permissions/privapp-permissions-cacamos.xml"
staged_privapp_permissions="$target_files_dir/SYSTEM/etc/permissions/privapp-permissions-cacamos.xml"
system_init="$lineage_root/system/core/rootdir/init.rc"
staged_system_init="$target_files_dir/SYSTEM/etc/init/hw/init.rc"
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
    "$staged_settings_apk" \
    "$staged_settings_provider_overlay" \
    "$staged_system_build_prop" \
    "$staged_product_build_prop" \
    "$bootanimation" \
    "$staged_bootanimation" \
    "$staged_kernel" \
    "$staged_boot" \
    "$staged_recovery" \
    "$staged_recovery_prop" \
    "$staged_usb_init" \
    "$staged_device_init" \
    "$boot_probe" \
    "$staged_boot_probe" \
    "$privapp_permissions" \
    "$staged_privapp_permissions" \
    "$system_init" \
    "$staged_system_init" \
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
    "$staged_adbd_capex" "$staged_settings_apk" "$staged_settings_provider_overlay" \
    "$staged_system_build_prop" \
    "$staged_product_build_prop" "$staged_kernel" "$staged_boot" "$staged_usb_init" \
    "$bootanimation" "$staged_bootanimation" \
    "$staged_recovery" "$staged_recovery_prop" "$staged_device_init" "$boot_probe" \
    "$staged_boot_probe" "$privapp_permissions" "$staged_privapp_permissions" "$system_init" \
    "$staged_system_init"; do
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
cmp -s "$boot_probe" "$staged_boot_probe" ||
    fail "target-files contains a stale autonomous boot probe"
cmp -s "$privapp_permissions" "$staged_privapp_permissions" ||
    fail "target-files contains a stale DeviceAsWebcam permission allowlist"
cmp -s "$bootanimation" "$staged_bootanimation" ||
    fail "target-files contains a stale or non-CaCamOS boot animation"
grep -Fq \
    "service cacamos_boot_probe /system/bin/sh /system/bin/cacamos_boot_probe.sh" \
    "$staged_system_init" ||
    fail "target-files does not start the autonomous boot probe"
grep -Fq "current_functions=0x80" "$staged_boot_probe" ||
    fail "compiled boot probe does not detect the applied UVC function"
grep -Fq "=== CACAMOS_BOOT_PROBE_NONFATAL ===" "$staged_boot_probe" ||
    fail "compiled boot probe can still reboot a working Android system"
python3 - "$staged_privapp_permissions" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
entries = root.findall("privapp-permissions")
if len(entries) != 1 or entries[0].get("package") != "com.android.DeviceAsWebcam":
    raise SystemExit("compiled DeviceAsWebcam privileged allowlist is invalid")
grants = {node.get("name") for node in entries[0].findall("permission")}
if grants != {"android.permission.WRITE_SECURE_SETTINGS"}:
    raise SystemExit(f"unexpected compiled DeviceAsWebcam grants: {sorted(grants)}")
PY
grep -aFq "Epoll_ctl DEL failed" "$staged_jni_lib" &&
    grep -aFq "Epoll_ctl ADD failed" "$staged_jni_lib" ||
    fail "compiled DeviceAsWebcam JNI library lacks the MI8 UVC epoll rearm"

grep -Fxq "ro.cacamos.appliance=true" "$staged_system_build_prop" ||
    fail "compiled system is not marked as a CaCamOS appliance"
grep -Fxq "ro.cacamos.version=1.0.0" "$staged_system_build_prop" ||
    fail "compiled system version is not CaCamOS 1.0.0"
grep -Fxq "ro.setupwizard.mode=DISABLED" "$staged_product_build_prop" ||
    fail "compiled product does not disable the setup wizard"
grep -Fxq "ro.product.product.model=CaCamOS MI 8 Webcam" \
    "$staged_product_build_prop" ||
    fail "compiled product does not expose the dedicated CaCamOS model"
grep -Fxq "ro.product.product.brand=CaCamOS" "$staged_product_build_prop" ||
    fail "compiled product does not expose the CaCamOS brand"
grep -aFq "CaCamOS recovery ADB enabled for appliance maintenance" \
    "$staged_recovery" ||
    fail "compiled recovery does not authorize unattended CaCamOS maintenance"
grep -Fxq "ro.debuggable=1" "$staged_recovery_prop" ||
    fail "compiled CaCamOS recovery is not debuggable"
grep -Fxq "ro.cacamos.appliance=true" "$staged_recovery_prop" ||
    fail "compiled recovery does not activate the CaCamOS maintenance policy"

python3 - "$target_files_dir" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
apks = {path.name: path for path in root.rglob("*.apk")}
required = {
    "DeviceAsWebcam.apk",
    "LatinIME.apk",
    "Settings.apk",
    "SystemUI.apk",
}
missing = sorted(required - apks.keys())
if missing:
    raise SystemExit(f"appliance target-files lacks baseline system APKs: {missing}")
if not any(path.name == "framework-nfc.jar" for path in root.rglob("*.jar")):
    raise SystemExit("appliance target-files lacks the Android NFC API framework jar")

forbidden = {
    "Aperture.apk",
    "Browser2.apk",
    "Calendar.apk",
    "Contacts.apk",
    "DeskClock.apk",
    "Dialer.apk",
    "Eleven.apk",
    "Gallery2.apk",
    "Jelly.apk",
    "Launcher3QuickStep.apk",
    "LineageSetupWizard.apk",
    "ManagedProvisioning.apk",
    "Music.apk",
    "NfcNciApex.apk",
    "Provision.apk",
    "QuickSearchBox.apk",
    "Tag.apk",
    "TrebuchetQuickStep.apk",
}
remaining = sorted(forbidden & apks.keys())
if remaining:
    raise SystemExit(f"consumer APKs remain in appliance target-files: {remaining}")

forbidden_files = {
    "android.hardware.nfc.hce.xml",
    "android.hardware.nfc.hcef.xml",
    "android.hardware.nfc.xml",
    "com.android.nfc_extras.xml",
    "com.android.nfcservices.apex",
    "com.android.nfcservices.capex",
    "com.nxp.mifare.xml",
    "libnfc-nci.conf",
    "libnfc-nxp.conf",
}
remaining = sorted(
    str(path.relative_to(root))
    for path in root.rglob("*")
    if path.is_file() and path.name in forbidden_files
)
if remaining:
    raise SystemExit(f"NFC files remain in appliance target-files: {remaining}")
PY
ok "target-files identifies CaCamOS 1.0.0 and contains only its appliance UI"

python3 - "$staged_bootanimation" <<'PY'
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    if archive.comment != b"CaCamOS":
        raise SystemExit("compiled boot animation lacks the CaCamOS marker")
    desc = archive.read("desc.txt")
    if b"1080 2248 30" not in desc:
        raise SystemExit("compiled boot animation does not target the MI8 display")
    frame = archive.read("part1/000.png")
    if frame[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("compiled boot animation frame is invalid")
    if struct.unpack(">II", frame[16:24]) != (1080, 2248):
        raise SystemExit("compiled boot animation frame has the wrong dimensions")
PY
ok "compiled boot animation is branded CaCamOS"

settings_provider_resources="$(
    "$host_bin/aapt2" dump resources "$staged_settings_provider_overlay"
)"
for setting in \
    def_device_provisioned \
    def_lockscreen_disabled \
    def_user_setup_complete; do
    grep -A1 -F "bool/$setting" <<<"$settings_provider_resources" |
        grep -Fq "() true" ||
        fail "compiled SettingsProvider overlay does not enable $setting"
done
grep -A1 -F "string/def_device_name_simple" <<<"$settings_provider_resources" |
    grep -Fq '() "CaCamOS Webcam"' ||
    fail "compiled SettingsProvider overlay lacks the CaCamOS device name"
ok "compiled first-boot defaults bypass setup and disable the lock screen"

python3 - "$staged_usb_init" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
for identity in (
    'configuration "CaCamOS UVC"',
    'function_name "CaCamOS Webcam"',
):
    if identity not in text:
        raise SystemExit(f"staged USB identity is missing: {identity}")
entries = []
for number, line in enumerate(text.splitlines(), 1):
    stripped = line.strip()
    if stripped.startswith("#") or "dwFrameInterval" not in stripped:
        continue
    entries.append((number, stripped.split("dwFrameInterval", 1)[1].strip()))
expected = r"333333\n666666\n"
if not entries or any(value != expected for _, value in entries):
    raise SystemExit(f"invalid staged UVC frame intervals: {entries}")

for profile in ("mjpeg/m1/576p", "mjpeg/m/576p"):
    base = f"/config/usb_gadget/g1/functions/uvc.0/streaming/{profile}"
    required = {
        f"write {base}/wWidth 1024",
        f"write {base}/wHeight 576",
        f"write {base}/dwMinBitRate 47185920",
        f"write {base}/dwMaxBitRate 141557760",
        f"write {base}/dwMaxVideoFrameBufferSize 1179648",
    }
    missing = sorted(entry for entry in required if entry not in text)
    if missing:
        raise SystemExit(f"staged {profile} has invalid MJPEG descriptors: {missing}")

for prefix in ("mjpeg/m1", "mjpeg/m"):
    hd = text.index(f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/720p")
    middle = text.index(
        f"mkdir /config/usb_gadget/g1/functions/uvc.0/streaming/{prefix}/576p"
    )
    if hd >= middle:
        raise SystemExit(f"staged {prefix} does not default to 1280x720")

for forbidden in (
    "streaming/mjpeg/m1/360p",
    "streaming/mjpeg/m/360p",
    "streaming/uncompressed/u/360p",
    "streaming/uncompressed/u1",
    "streaming/header/h1/u1",
):
    if forbidden in text:
        raise SystemExit(f"staged obsolete UVC mode remains: {forbidden}")

if (
    "streaming/mjpeg/m1 /config/usb_gadget/g1/functions/uvc.0/"
    "streaming/header/h1/m1"
) not in text:
    raise SystemExit("staged high-speed UVC header does not expose MJPEG")
PY
if grep -Fq "vendor.sys.usb.adb.disabled" "$staged_device_init"; then
    fail "staged dipper init still contains the obsolete USB-ADB property workaround"
fi
ok "target-files carries the current APK, JNI library, permissions, kernel and USB policies"

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
if b"uvcvideo: stream interval" not in image:
    raise SystemExit("compiled kernel lacks frame-paced UVC request scheduling")
if b"uvcvideo: missed isochronous transfer" not in image:
    raise SystemExit("compiled kernel lacks recoverable isochronous transfer handling")
if b"uvcvideo: failed to prioritize USB submit worker" not in image:
    raise SystemExit("compiled kernel lacks real-time UVC request submission")
if b"aborted incomplete frame" in image:
    raise SystemExit("compiled kernel still contains the freeze-inducing UVC frame abort")
PY
ok "compiled kernel contains the real-time frame-paced isochronous request flow"
for symbol in uvcg_complete_buffer uvcg_video_prep_requests uvcg_video_hw_submit; do
    nm "$kernel_vmlinux" |
        awk -v symbol="$symbol" '$3 == symbol { found = 1 } END { exit !found }' ||
        fail "compiled kernel lacks required UVC symbol: $symbol"
done
ok "compiled kernel retains buffers and submits requests outside completion context"

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
    b"attachPreviewIfReady",
    b"isWebcamReady",
    b"CaCamUvcSetup",
    b"waiting-for-android-runtime generation=",
    b"waiting-for-uvc-node generation=",
    b"receiver-deferred-until-user-unlocked",
    b"uvc-disconnected generation=",
    b"controller-stop-failed generation=",
    b"controller-destroy-failed generation=",
    b"isUserUnlocked",
    b"/cache/recovery/cacamos-boot-state.log",
):
    if marker not in dex:
        raise SystemExit(f"compiled DeviceAsWebcam APK lacks {marker.decode()}")
if b"LOCKED_BOOT_COMPLETED" in dex:
    raise SystemExit("compiled DeviceAsWebcam still starts camera service before user unlock")
PY
python3 - "$staged_settings_apk" <<'PY'
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
if b"isUsbAdbDisabledByProduct" not in dex:
    raise SystemExit("compiled Settings APK still exposes appliance USB debugging")
PY
ok "compiled credential-safe startup, recovery, FPS pacing and maintenance policy"

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
    "android.permission.WRITE_SECURE_SETTINGS",
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
    'android.intent.action.MY_PACKAGE_REPLACED' \
    'com.android.DeviceAsWebcam.action.PREPARE_UVC' \
    'android.intent.category.HOME' \
    'android.permission.MANAGE_USB'; do
    grep -Fq "$marker" "$apk_xmltree" ||
        fail "compiled APK manifest is missing: $marker"
done
if grep -Fq 'android.intent.action.LOCKED_BOOT_COMPLETED' "$apk_xmltree"; then
    fail "compiled APK starts its camera service before credential unlock"
fi
grep -Eq 'persistent\([^)]*\)=true' "$apk_xmltree" ||
    fail "compiled DeviceAsWebcam application is not persistent"
grep -Eq 'allowBackup\([^)]*\)=false' "$apk_xmltree" ||
    fail "compiled DeviceAsWebcam application still permits backup"
grep -Eq 'launchMode\([^)]*\)=2' "$apk_xmltree" ||
    fail "compiled webcam HOME activity is not singleTask"
direct_boot_count="$(grep -Fc 'directBootAware(0x01010505)=true' "$apk_xmltree")"
(( direct_boot_count >= 3 )) ||
    fail "receiver, activity and service are not all direct-boot aware"
grep -Fq 'foregroundServiceType(0x01010599)=0x00000040' "$apk_xmltree" ||
    fail "compiled service is not declared as a camera foreground service"
ok "platform-signed persistent HOME APK and audited compiled permission set"

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
