#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
out_dir="$repo_root/dist/magisk-test"
api_url="https://download.lineageos.org/api/v2/devices/cmi/builds"
adb_bin="${ADB:-adb}"

usage() {
    cat >&2 <<'EOF'
Usage:
  download-lineage-boot.sh --current
  download-lineage-boot.sh --latest
  download-lineage-boot.sh --date YYYY-MM-DD

--current refuses to download if the installed build date is no longer present
in the official LineageOS API.
EOF
}

mode="${1:-}"
value="${2:-}"
if [[ -z "$mode" ]]; then
    usage
    exit 2
fi

mkdir -p "$out_dir"

python3 - "$api_url" "$mode" "$value" "$out_dir" "$adb_bin" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import urllib.request

api_url, mode, value, out_dir, adb_bin = sys.argv[1:]
out_dir = pathlib.Path(out_dir)

with urllib.request.urlopen(api_url) as response:
    builds = json.load(response)

target_date = None
if mode == "--latest":
    target_date = builds[0]["date"]
elif mode == "--date":
    if not value:
        raise SystemExit("--date requires YYYY-MM-DD")
    target_date = value
elif mode == "--current":
    lineage = subprocess.check_output(
        [adb_bin, "shell", "getprop", "ro.lineage.version"],
        text=True,
    ).strip().replace("\r", "")
    match = re.search(r"23\.2-(\d{8})-", lineage)
    if not match:
        raise SystemExit(f"Cannot parse ro.lineage.version: {lineage!r}")
    raw = match.group(1)
    target_date = f"{raw[:4]}-{raw[4:6]}-{raw[6:]}"
else:
    raise SystemExit(f"unknown mode: {mode}")

build = next((item for item in builds if item.get("date") == target_date), None)
if not build:
    available = ", ".join(item.get("date", "?") for item in builds)
    raise SystemExit(
        f"LineageOS cmi build {target_date} is not available from the official API. "
        f"Available: {available}"
    )

boot = next((item for item in build["files"] if item.get("filename") == "boot.img"), None)
if not boot:
    raise SystemExit(f"boot.img missing for build {target_date}")

filename = f"lineage-23.2-{target_date.replace('-', '')}-nightly-cmi-boot.img"
out = out_dir / filename

if not out.exists() or out.stat().st_size != boot["size"]:
    print(f"Downloading {boot['url']}")
    urllib.request.urlretrieve(boot["url"], out)

import hashlib
digest = hashlib.sha256(out.read_bytes()).hexdigest()
if digest != boot["sha256"]:
    out.unlink(missing_ok=True)
    raise SystemExit(f"sha256 mismatch for {out}: {digest} != {boot['sha256']}")

(out.with_suffix(out.suffix + ".sha256")).write_text(f"{digest}  {out.name}\n")
print(f"{digest}  {out}")
PY
