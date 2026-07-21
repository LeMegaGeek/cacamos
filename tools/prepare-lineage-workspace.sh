#!/usr/bin/env bash
set -euo pipefail

repo_url="https://storage.googleapis.com/git-repo-downloads/repo"
repo_bin="${REPO:-repo}"
install_repo=false
init_workspace=false
sync_workspace=false
write_manifest=false
sync_webcam_deps=false

usage() {
    cat >&2 <<'EOF'
Usage: prepare-lineage-workspace.sh [options] <cmi|dipper> /path/to/lineageos

Options:
  --install-repo   Install the repo launcher in ~/.local/bin when repo is missing.
  --init           Run repo init for the selected LineageOS branch.
  --local-manifest Write the device, kernel and vendor local manifest.
  --sync-webcam-deps
                   Sync only projects needed to apply and verify the webcam addon.
  --sync           Run repo sync after init. This is large and can take hours.

Defaults are read-only checks and printed next commands.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-repo)
            install_repo=true
            shift
            ;;
        --init)
            init_workspace=true
            shift
            ;;
        --local-manifest)
            write_manifest=true
            shift
            ;;
        --sync-webcam-deps)
            sync_webcam_deps=true
            write_manifest=true
            shift
            ;;
        --sync)
            sync_workspace=true
            init_workspace=true
            write_manifest=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            fail "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

device="${1:-}"
workspace="${2:-}"
[[ -n "$device" && -n "$workspace" ]] || { usage; exit 2; }

case "$device" in
    cmi)
        lineage_branch="lineage-23.2"
        breakfast_target="cmi"
        addon_script="lineageos/cmi/tools/install-into-lineage.sh"
        device_common_path="device/xiaomi/sm8250-common"
        kernel_path="kernel/xiaomi/sm8250"
        vendor_common_path="vendor/xiaomi/sm8250-common"
        ;;
    dipper)
        lineage_branch="lineage-22.2"
        breakfast_target="dipper"
        addon_script="lineageos/dipper/tools/install-into-lineage.sh"
        device_common_path="device/xiaomi/sdm845-common"
        kernel_path="kernel/xiaomi/sdm845"
        vendor_common_path="vendor/xiaomi/sdm845-common"
        ;;
    *)
        fail "unsupported device: $device"
        ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="$(mkdir -p "$workspace" && cd "$workspace" && pwd)"
webcam_sync_projects=(
    build/make
    device/xiaomi/"$device"
    "$device_common_path"
    frameworks/base
    hardware/xiaomi
    "$kernel_path"
    packages/services/DeviceAsWebcam
    system/sepolicy
    trusty/vendor/google/aosp
    vendor/qcom/opensource/usb
    vendor/xiaomi/"$device"
    "$vendor_common_path"
)

write_local_manifest() {
    local manifest_dir="$workspace/.repo/local_manifests"
    local manifest_file="$manifest_dir/cacam-os-$device.xml"

    [[ -d "$workspace/.repo" ]] || fail "workspace is not initialized; run with --init before --local-manifest"
    mkdir -p "$manifest_dir"

    case "$device" in
        cmi)
            cat >"$manifest_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="themuppets" fetch="https://github.com/TheMuppets" />

  <project path="device/xiaomi/cmi" name="LineageOS/android_device_xiaomi_cmi" revision="refs/heads/lineage-23.2" />
  <project path="device/xiaomi/sm8250-common" name="LineageOS/android_device_xiaomi_sm8250-common" revision="refs/heads/lineage-23.2" />
  <project path="hardware/xiaomi" name="LineageOS/android_hardware_xiaomi" revision="refs/heads/lineage-23.2" />
  <project path="kernel/xiaomi/sm8250" name="LineageOS/android_kernel_xiaomi_sm8250" revision="refs/heads/lineage-23.2" />
  <project path="vendor/xiaomi/cmi" name="proprietary_vendor_xiaomi_cmi" remote="themuppets" revision="refs/heads/lineage-23.2" />
  <project path="vendor/xiaomi/sm8250-common" name="proprietary_vendor_xiaomi_sm8250-common" remote="themuppets" revision="refs/heads/lineage-23.2" />
</manifest>
EOF
            ;;
        dipper)
            cat >"$manifest_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="themuppets" fetch="https://github.com/TheMuppets" />

  <project path="device/xiaomi/dipper" name="LineageOS/android_device_xiaomi_dipper" revision="refs/heads/lineage-22.2" />
  <project path="device/xiaomi/sdm845-common" name="LineageOS/android_device_xiaomi_sdm845-common" revision="refs/heads/lineage-22.2" />
  <project path="hardware/xiaomi" name="LineageOS/android_hardware_xiaomi" revision="refs/heads/lineage-22.2" />
  <project path="kernel/xiaomi/sdm845" name="LineageOS/android_kernel_xiaomi_sdm845" revision="refs/heads/lineage-22.2" />
  <project path="vendor/xiaomi/dipper" name="proprietary_vendor_xiaomi_dipper" remote="themuppets" revision="refs/heads/lineage-22.2" />
  <project path="vendor/xiaomi/sdm845-common" name="proprietary_vendor_xiaomi_sdm845-common" remote="themuppets" revision="refs/heads/lineage-22.2" />
</manifest>
EOF
            ;;
    esac

    printf 'Wrote local manifest: %s\n' "$manifest_file"
}

missing=()
for cmd in git curl python3 java javac make ninja zip unzip bc ccache bison flex lz4 brotli; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if command -v "$repo_bin" >/dev/null 2>&1; then
    repo_bin="$(command -v "$repo_bin")"
elif [[ "$repo_bin" == "repo" && -x "$HOME/.local/bin/repo" ]]; then
    repo_bin="$HOME/.local/bin/repo"
else
    if [[ "$install_repo" == true ]]; then
        user_bin="$HOME/.local/bin"
        mkdir -p "$user_bin"
        curl -fsSL "$repo_url" -o "$user_bin/repo"
        chmod +x "$user_bin/repo"
        repo_bin="$user_bin/repo"
        printf 'Installed repo launcher: %s\n' "$repo_bin"
    else
        missing+=("repo")
    fi
fi

printf 'CaCam OS LineageOS workspace helper\n\n'
printf 'Device: %s\n' "$device"
printf 'Branch: %s\n' "$lineage_branch"
printf 'Workspace: %s\n\n' "$workspace"

if [[ "${#missing[@]}" -gt 0 ]]; then
    printf 'Missing commands: %s\n\n' "${missing[*]}"
    cat <<'EOF'
Ubuntu/Debian package hint:
  sudo apt update
  sudo apt install git curl python3 openjdk-21-jdk make ninja-build zip unzip bc bison flex lz4 brotli ccache repo

If repo is missing and you do not want a system install, rerun with:
  prepare-lineage-workspace.sh --install-repo <cmi|dipper> /path/to/lineageos

EOF
fi

if [[ "$init_workspace" == true ]]; then
    printf 'Running repo init...\n'
    (cd "$workspace" && "$repo_bin" init -u https://github.com/LineageOS/android.git -b "$lineage_branch" --git-lfs)
fi

if [[ "$write_manifest" == true ]]; then
    write_local_manifest
fi

if [[ "$sync_webcam_deps" == true ]]; then
    printf 'Running minimal webcam dependency sync. This is not enough for a full ROM build.\n'
    (cd "$workspace" && "$repo_bin" sync --no-manifest-update -c --no-clone-bundle --no-tags -j"$(nproc)" "${webcam_sync_projects[@]}")
fi

if [[ "$sync_workspace" == true ]]; then
    printf 'Running repo sync. This can take a long time.\n'
    (cd "$workspace" && "$repo_bin" sync -c --no-clone-bundle --no-tags -j"$(nproc)")
fi

cat <<EOF
Next commands:
  cd $workspace
  $repo_bin init -u https://github.com/LineageOS/android.git -b $lineage_branch --git-lfs
  $repo_root/tools/prepare-lineage-workspace.sh --local-manifest $device $workspace
  $repo_root/tools/prepare-lineage-workspace.sh --sync-webcam-deps $device $workspace
  $repo_bin sync -c --no-clone-bundle --no-tags -j\$(nproc)
  $repo_root/$addon_script $workspace
  source build/envsetup.sh
  breakfast $breakfast_target
  mka bacon
EOF
