#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
addon_root="$(cd "$script_dir/.." && pwd)"
lineage_root="${1:-}"
output="${2:-}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -n "$lineage_root" ]] ||
    fail "usage: $(basename "$0") /path/to/lineage [output.zip]"
lineage_root="$(cd "$lineage_root" && pwd)"
product_out="$lineage_root/out/target/product/dipper"
host_bin="$lineage_root/out/host/linux-x86/bin"
full_ota="$product_out/lineage_dipper-ota.zip"
boot_img="$product_out/boot.img"
vbmeta_img="$product_out/vbmeta.img"
signapk="$lineage_root/out/host/linux-x86/framework/signapk.jar"
certificate="$lineage_root/build/make/target/product/security/testkey.x509.pem"
private_key="$lineage_root/build/make/target/product/security/testkey.pk8"
updater_script="$addon_root/boot-ota/updater-script"

if [[ -z "$output" ]]; then
    output="$product_out/CaCamOS-R19-dipper-boot-ota.zip"
fi
output="$(realpath -m "$output")"

for file in \
    "$full_ota" \
    "$boot_img" \
    "$vbmeta_img" \
    "$signapk" \
    "$certificate" \
    "$private_key" \
    "$updater_script"; do
    [[ -f "$file" ]] || fail "missing required file: $file"
done
for command in java unzip zip sha256sum; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done
[[ -x "$host_bin/check_ota_package_signature" ]] ||
    fail "missing OTA signature verifier"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cacamos-boot-ota.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
package_dir="$work_dir/package"
mkdir -p "$package_dir/META-INF/com/google/android"

unzip -p "$full_ota" META-INF/com/google/android/update-binary \
    >"$package_dir/META-INF/com/google/android/update-binary"
install -m 0644 "$updater_script" \
    "$package_dir/META-INF/com/google/android/updater-script"
install -m 0644 "$boot_img" "$package_dir/boot.img"
install -m 0644 "$vbmeta_img" "$package_dir/vbmeta.img"

(
    cd "$package_dir"
    zip -q -0 -r "$work_dir/unsigned.zip" .
)

mkdir -p "$(dirname "$output")"
java -Xmx1024m -Djava.library.path="$lineage_root/out/host/linux-x86/lib64" \
    -jar "$signapk" -w "$certificate" "$private_key" \
    "$work_dir/unsigned.zip" "$output"

"$host_bin/check_ota_package_signature" "$certificate" "$output" >/dev/null
unzip -tq "$output" >/dev/null
sha256sum "$output"
