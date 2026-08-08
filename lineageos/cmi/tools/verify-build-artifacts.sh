#!/usr/bin/env bash
set -euo pipefail

lineage_root="${1:-}"
ota_path="${2:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cacamos_version="$(tr -d '\r\n' < "$script_dir/../VERSION")"
[[ "$cacamos_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf 'FAIL: invalid CaCamOS version: %s\n' "$cacamos_version" >&2
    exit 1
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -n "$lineage_root" ]] || fail "missing LineageOS root"
lineage_root="$(cd "$lineage_root" && pwd)"

if [[ -z "$ota_path" ]]; then
    ota_path="$lineage_root/out/target/product/cmi/lineage_cmi-ota.zip"
fi
[[ "$ota_path" = /* ]] || ota_path="$PWD/$ota_path"

[[ -s "$ota_path" ]] || fail "missing or empty OTA: $ota_path"
command -v unzip >/dev/null 2>&1 || fail "unzip is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

printf 'Checking OTA archive integrity...\n'
unzip -tq "$ota_path" >/dev/null || fail "corrupt OTA archive"

metadata="$(unzip -p "$ota_path" META-INF/com/android/metadata)"
grep -qx 'pre-device=cmi' <<< "$metadata" || fail "OTA is not for cmi"
grep -qx 'ota-type=BLOCK' <<< "$metadata" || fail "unexpected OTA type"

entries="$(unzip -Z1 "$ota_path")"
for entry in \
    META-INF/com/google/android/update-binary \
    META-INF/com/google/android/updater-script \
    boot.img \
    recovery.img \
    system.new.dat.br \
    vendor.new.dat.br; do
    grep -Fxq "$entry" <<< "$entries" || fail "OTA entry is missing: $entry"
done

updater_script="$(unzip -p "$ota_path" META-INF/com/google/android/updater-script)"
grep -Fq 'package_extract_file("recovery.img", "/dev/block/bootdevice/by-name/recovery");' \
    <<< "$updater_script" || fail "OTA does not install the CaCamOS recovery image"

product_out="$lineage_root/out/target/product/cmi"
target_files="$product_out/obj/PACKAGING/target_files_intermediates/lineage_cmi-target_files"
system_prop="$product_out/system/build.prop"
vendor_prop="$product_out/vendor/build.prop"
apk="$product_out/system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk"
recovery_bin="$target_files/RECOVERY/RAMDISK/system/bin/recovery"
target_recovery="$target_files/IMAGES/recovery.img"
host_bin="$lineage_root/out/host/linux-x86/bin"
aapt2="$lineage_root/out/host/linux-x86/bin/aapt2"
signature_checker="$host_bin/check_ota_package_signature"
ota_cert="$lineage_root/build/make/target/product/security/testkey.x509.pem"

[[ -f "$system_prop" ]] || fail "missing built system properties"
[[ -f "$vendor_prop" ]] || fail "missing built vendor properties"
[[ -s "$recovery_bin" ]] || fail "missing compiled recovery binary"
[[ -s "$target_recovery" ]] || fail "missing target-files recovery image"
[[ -x "$signature_checker" ]] || fail "missing OTA signature checker"
[[ -s "$ota_cert" ]] || fail "missing OTA signing certificate"
grep -qx 'ro.cacamos.appliance=true' "$system_prop" || fail "appliance property is missing"
grep -qx "ro.cacamos.version=$cacamos_version" "$system_prop" ||
    fail "unexpected CaCamOS version"
grep -qx 'ro.product.system.brand=CaCamOS' "$system_prop" || fail "CaCamOS brand is missing"
grep -qx 'ro.product.system.model=CaCamOS Mi 10 Pro Webcam' "$system_prop" ||
    fail "unexpected CaCamOS model"
grep -qx 'vendor.usb.product_string=CaCamOS Webcam' "$vendor_prop" ||
    fail "USB product identity is missing"

for artifact in \
    "$apk" \
    "$product_out/system/lib64/libjni_deviceAsWebcam.so" \
    "$product_out/product/overlay/CaCamOsDeviceAsWebcamCmi.apk"; do
    [[ -s "$artifact" ]] || fail "missing built webcam artifact: $artifact"
done

[[ -x "$aapt2" ]] || fail "missing aapt2: $aapt2"
apk_permissions="$($aapt2 dump permissions "$apk")"
grep -Fq "uses-permission: name='android.permission.DEVICE_POWER'" \
    <<< "$apk_permissions" || fail "compiled webcam cannot force display sleep"
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
for marker in (b"preview-screen-timeout", b"goToSleep", b"onUserInteraction"):
    if marker not in dex:
        raise SystemExit(
            f"compiled DeviceAsWebcam APK lacks {marker.decode()}"
        )
PY

for marker in \
    'CaCamOS recovery ADB enabled for appliance maintenance' \
    'CaCamOS: optional /cache is unavailable; continuing installation'; do
    grep -aFq "$marker" "$recovery_bin" ||
        fail "compiled recovery lacks policy: $marker"
done

printf 'Checking OTA signature and embedded recovery...\n'
"$signature_checker" "$ota_cert" "$ota_path" >/dev/null 2>&1 ||
    fail "OTA signature verification failed"

embedded_recovery_digest="$(unzip -p "$ota_path" recovery.img | sha256sum | awk '{ print $1 }')"
target_recovery_digest="$(sha256sum "$target_recovery" | awk '{ print $1 }')"
[[ "$embedded_recovery_digest" == "$target_recovery_digest" ]] ||
    fail "embedded recovery does not match target-files recovery"

digest="$(sha256sum "$ota_path" | awk '{ print $1 }')"
size_bytes="$(stat -c '%s' "$ota_path")"

printf 'PASS: CaCamOS MI10 Pro OTA is structurally valid.\n'
printf '  File:   %s\n' "$ota_path"
printf '  Size:   %s bytes\n' "$size_bytes"
printf '  SHA256: %s\n' "$digest"
