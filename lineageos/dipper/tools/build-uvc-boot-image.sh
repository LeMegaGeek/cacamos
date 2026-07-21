#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
api_url="https://download.lineageos.org/api/v2/devices/dipper/builds"

lineage_root=""
kernel_image=""
boot_img=""
build_date=""
out_img=""

usage() {
    cat >&2 <<'EOF'
Usage:
  build-uvc-boot-image.sh --lineage-root /path/to/lineage \
    --kernel-image /path/to/Image.gz-dtb --date YYYY-MM-DD [--out boot.img]

  build-uvc-boot-image.sh --lineage-root /path/to/lineage \
    --kernel-image /path/to/Image.gz-dtb --boot-img /path/to/official-boot.img [--date YYYY-MM-DD] [--out boot.img]

Builds a MI8 CaCam OS test boot image by reusing the official LineageOS boot
parameters and ramdisk, replacing only the kernel with a CaCam OS UVC
Image.gz-dtb.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lineage-root)
            lineage_root="${2:-}"
            shift 2
            ;;
        --kernel-image)
            kernel_image="${2:-}"
            shift 2
            ;;
        --boot-img)
            boot_img="${2:-}"
            shift 2
            ;;
        --date)
            build_date="${2:-}"
            shift 2
            ;;
        --out)
            out_img="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            fail "unknown argument: $1"
            ;;
    esac
done

[[ -n "$lineage_root" ]] || { usage; fail "--lineage-root is required"; }
[[ -n "$kernel_image" ]] || { usage; fail "--kernel-image is required"; }

lineage_root="$(cd "$lineage_root" && pwd)"
kernel_image="$(realpath "$kernel_image")"
[[ -f "$kernel_image" ]] || fail "kernel image not found: $kernel_image"

unpack_bootimg="$lineage_root/system/tools/mkbootimg/unpack_bootimg.py"
mkbootimg="$lineage_root/system/tools/mkbootimg/mkbootimg.py"
[[ -f "$unpack_bootimg" ]] || fail "missing unpack_bootimg.py under $lineage_root"
[[ -f "$mkbootimg" ]] || fail "missing mkbootimg.py under $lineage_root"

if [[ -z "$build_date" && -z "$boot_img" ]]; then
    usage
    fail "either --date or --boot-img is required"
fi

if [[ -n "$build_date" && ! "$build_date" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "--date must be YYYY-MM-DD"
fi

raw_date="${build_date//-/}"
if [[ -z "$raw_date" && "$(basename "$boot_img")" =~ (20[0-9]{6}) ]]; then
    raw_date="${BASH_REMATCH[1]}"
fi
[[ -n "$raw_date" ]] || raw_date="custom"

work_dir="$repo_root/dist/magisk-test/build-dipper-uvc-boot-$raw_date"
mkdir -p "$work_dir"

if [[ -z "$boot_img" ]]; then
    command -v curl >/dev/null 2>&1 || fail "curl not found"
    command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not found"

    read -r boot_url boot_sha boot_size <<EOF_BOOT
$(python3 - "$api_url" "$build_date" <<'PY'
import json
import sys
import urllib.request

api_url, build_date = sys.argv[1:]
with urllib.request.urlopen(api_url, timeout=30) as response:
    builds = json.load(response)

build = next((item for item in builds if item.get("date") == build_date), None)
if not build:
    available = ", ".join(item.get("date", "?") for item in builds)
    raise SystemExit(f"LineageOS dipper build {build_date} is not available. Available: {available}")

boot = next((item for item in build.get("files", []) if item.get("filename") == "boot.img"), None)
if not boot:
    raise SystemExit(f"boot.img missing for LineageOS dipper build {build_date}")

print(boot["url"], boot["sha256"], boot["size"])
PY
)
EOF_BOOT

    boot_img="$work_dir/lineage-22.2-$raw_date-nightly-dipper-boot.img"
    if [[ ! -f "$boot_img" || "$(stat -c %s "$boot_img")" != "$boot_size" ]]; then
        printf 'Downloading %s\n' "$boot_url"
        rm -f "$boot_img" "$boot_img.tmp"
        curl -L --fail --output "$boot_img.tmp" "$boot_url"
        mv "$boot_img.tmp" "$boot_img"
    fi
    digest="$(sha256sum "$boot_img" | awk '{print $1}')"
    [[ "$digest" == "$boot_sha" ]] || fail "sha256 mismatch for $boot_img: $digest != $boot_sha"
    printf '%s  %s\n' "$digest" "$boot_img" > "$boot_img.sha256"
else
    boot_img="$(realpath "$boot_img")"
    [[ -f "$boot_img" ]] || fail "boot image not found: $boot_img"
fi

if [[ -z "$out_img" ]]; then
    out_img="$repo_root/dist/magisk-test/CaCamOS-dipper-uvc-boot-$raw_date.img"
fi
out_img="$(realpath -m "$out_img")"
mkdir -p "$(dirname "$out_img")"

rm -rf "$work_dir/unpacked-official" "$work_dir/unpacked-output"
mkdir -p "$work_dir/unpacked-official" "$work_dir/unpacked-output"

python3 "$unpack_bootimg" --boot_img "$boot_img" --out "$work_dir/unpacked-official" \
    --format mkbootimg -0 > "$work_dir/mkbootimg.args0"

args=()
while IFS= read -r -d '' arg; do
    args+=("$arg")
done < "$work_dir/mkbootimg.args0"

for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--kernel" ]]; then
        args[$((i + 1))]="$kernel_image"
        break
    fi
done

python3 "$mkbootimg" "${args[@]}" -o "$out_img"
sha256sum "$out_img" > "$out_img.sha256"

python3 "$unpack_bootimg" --boot_img "$out_img" --out "$work_dir/unpacked-output" \
    --format info > "$work_dir/output-info.txt"

kernel_expected="$(sha256sum "$kernel_image" | awk '{print $1}')"
kernel_embedded="$(sha256sum "$work_dir/unpacked-output/kernel" | awk '{print $1}')"
[[ "$kernel_expected" == "$kernel_embedded" ]] ||
    fail "embedded kernel mismatch: $kernel_embedded != $kernel_expected"

cat <<EOF
Built MI8 CaCam OS UVC boot image:
  $out_img
  sha256=$(
    awk '{print $1}' "$out_img.sha256"
  )

Official boot source:
  $boot_img

Kernel:
  $kernel_image
  sha256=$kernel_expected

Verification:
  embedded kernel sha256 matches
  unpack info: $work_dir/output-info.txt
EOF
