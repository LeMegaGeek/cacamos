#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out_dir="$repo_root/dist/magisk-test"
api_url="https://download.lineageos.org/api/v2/devices/cmi/builds"
adb_bin="${ADB:-adb}"

usage() {
    cat >&2 <<'EOF'
Usage:
  prepare-lineage-magisk-test.sh --latest [--with-rom]
  prepare-lineage-magisk-test.sh --date YYYY-MM-DD [--with-rom]

Downloads and verifies the official LineageOS cmi boot image for the selected
build, patches it with Magisk, and writes a local test manifest.

--with-rom also downloads the full signed ROM zip for updating the phone.

This script never flashes, sideloads, or boots anything.
EOF
}

mode="${1:-}"
value=""
with_rom=0

case "$mode" in
    --latest)
        shift
        ;;
    --date)
        value="${2:-}"
        [[ -n "$value" ]] || { usage; exit 2; }
        shift 2
        ;;
    *)
        usage
        exit 2
        ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-rom)
            with_rom=1
            shift
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

command -v "$adb_bin" >/dev/null 2>&1 || { echo "adb not found" >&2; exit 127; }
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 127; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum not found" >&2; exit 127; }

mkdir -p "$out_dir"

read -r build_date version boot_url boot_sha boot_size rom_url rom_sha rom_size rom_name <<EOF_BUILD
$(python3 - "$api_url" "$mode" "$value" <<'PY'
import json
import sys
import urllib.request

api_url, mode, value = sys.argv[1:]
with urllib.request.urlopen(api_url, timeout=30) as response:
    builds = json.load(response)

if mode == "--latest":
    target_date = builds[0]["date"]
elif mode == "--date":
    target_date = value
else:
    raise SystemExit(f"unknown mode: {mode}")

build = next((item for item in builds if item.get("date") == target_date), None)
if not build:
    available = ", ".join(item.get("date", "?") for item in builds)
    raise SystemExit(
        f"LineageOS cmi build {target_date} is not available from the official API. "
        f"Available: {available}"
    )

files = build.get("files", [])
boot = next((item for item in files if item.get("filename") == "boot.img"), None)
rom = next((item for item in files if item.get("filename", "").endswith("-signed.zip")), None)
if not boot:
    raise SystemExit(f"boot.img missing for build {target_date}")
if not rom:
    raise SystemExit(f"signed ROM zip missing for build {target_date}")

print(
    target_date,
    build.get("version", "unknown"),
    boot["url"],
    boot["sha256"],
    boot["size"],
    rom["url"],
    rom["sha256"],
    rom["size"],
    rom["filename"],
)
PY
)
EOF_BUILD

raw_date="${build_date//-/}"
boot_img="$out_dir/lineage-${version}-${raw_date}-nightly-cmi-boot.img"
rom_zip="$out_dir/$rom_name"
manifest="$out_dir/lineage-${version}-${raw_date}-nightly-cmi-magisk-test.txt"

download_verified() {
    local url="$1"
    local out="$2"
    local expected_sha="$3"
    local expected_size="$4"

    if [[ ! -f "$out" || "$(stat -c %s "$out")" != "$expected_size" ]]; then
        echo "Downloading $url"
        rm -f "$out" "$out.tmp"
        curl -L --fail --output "$out.tmp" "$url"
        mv "$out.tmp" "$out"
    fi

    local digest
    digest="$(sha256sum "$out" | awk '{print $1}')"
    if [[ "$digest" != "$expected_sha" ]]; then
        rm -f "$out"
        echo "sha256 mismatch for $out: $digest != $expected_sha" >&2
        exit 1
    fi
    printf '%s  %s\n' "$digest" "$out" > "$out.sha256"
}

"$adb_bin" wait-for-device
device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
lineage="$("$adb_bin" shell getprop ro.lineage.version | tr -d '\r')"
[[ "$device" == "cmi" ]] || { echo "Expected cmi, got ${device:-unset}" >&2; exit 1; }

download_verified "$boot_url" "$boot_img" "$boot_sha" "$boot_size"
if [[ "$with_rom" == 1 ]]; then
    download_verified "$rom_url" "$rom_zip" "$rom_sha" "$rom_size"
fi

"$script_dir/patch-boot-with-magisk.sh" "$boot_img"

patched_glob="$out_dir/$(basename "${boot_img%.img}")-magisk-*-patched.img"
patched_img="$(compgen -G "$patched_glob" | sort | tail -n 1 || true)"
if [[ -z "$patched_img" ]]; then
    echo "patched boot image was not produced for $boot_img" >&2
    exit 1
fi

{
    echo "CaCam OS cmi Magisk test preparation"
    echo "Generated: $(date -Iseconds)"
    echo
    echo "Phone:"
    echo "  ro.product.device=$device"
    echo "  ro.lineage.version=${lineage:-unset}"
    echo
    echo "Target LineageOS build:"
    echo "  version=$version"
    echo "  date=$build_date"
    echo "  raw_date=$raw_date"
    echo
    echo "Official artifacts:"
    echo "  boot=$boot_img"
    echo "  boot_sha256=$boot_sha"
    if [[ "$with_rom" == 1 ]]; then
        echo "  rom=$rom_zip"
        echo "  rom_sha256=$rom_sha"
    else
        echo "  rom=not downloaded; rerun with --with-rom if an update package is needed"
        echo "  rom_url=$rom_url"
        echo "  rom_sha256=$rom_sha"
    fi
    echo
    echo "Magisk patched boot:"
    echo "  patched=$patched_img"
    echo "  patched_sha256=$(sha256sum "$patched_img" | awk '{print $1}')"
    echo
    if [[ "$lineage" == *"$raw_date"* ]]; then
        echo "Status: phone build matches the patched boot date."
        echo "Next:"
        echo "  $script_dir/temporary-boot-patched.sh $patched_img"
    else
        echo "Status: phone build does not match the patched boot date."
        echo "Next:"
        echo "  update the phone to $raw_date first, or prepare a patched boot for ${lineage:-the installed build}."
    fi
} > "$manifest"

cat "$manifest"
