#!/usr/bin/env bash
set -euo pipefail

lineage_root="${1:-}"
ota_path="${2:-}"

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

product_out="$lineage_root/out/target/product/cmi"
system_prop="$product_out/system/build.prop"
vendor_prop="$product_out/vendor/build.prop"

[[ -f "$system_prop" ]] || fail "missing built system properties"
[[ -f "$vendor_prop" ]] || fail "missing built vendor properties"
grep -qx 'ro.cacamos.appliance=true' "$system_prop" || fail "appliance property is missing"
grep -qx 'ro.cacamos.version=1.2.0' "$system_prop" || fail "unexpected CaCamOS version"
grep -qx 'ro.product.system.brand=CaCamOS' "$system_prop" || fail "CaCamOS brand is missing"
grep -qx 'ro.product.system.model=CaCamOS Mi 10 Pro Webcam' "$system_prop" ||
    fail "unexpected CaCamOS model"
grep -qx 'vendor.usb.product_string=CaCamOS Webcam' "$vendor_prop" ||
    fail "USB product identity is missing"

for artifact in \
    "$product_out/system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk" \
    "$product_out/system/lib64/libjni_deviceAsWebcam.so" \
    "$product_out/product/overlay/CaCamOsDeviceAsWebcamCmi.apk"; do
    [[ -s "$artifact" ]] || fail "missing built webcam artifact: $artifact"
done

digest="$(sha256sum "$ota_path" | awk '{ print $1 }')"
size_bytes="$(stat -c '%s' "$ota_path")"

printf 'PASS: CaCamOS MI10 Pro OTA is structurally valid.\n'
printf '  File:   %s\n' "$ota_path"
printf '  Size:   %s bytes\n' "$size_bytes"
printf '  SHA256: %s\n' "$digest"
