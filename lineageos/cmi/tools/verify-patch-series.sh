#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patch_dir="$(cd "$script_dir/../patches" && pwd)"
lineage_root=""
match_worktrees=0

usage() {
    cat >&2 <<'EOF'
Usage:
  verify-patch-series.sh [--match-worktrees] /path/to/lineageos

Checks every CaCamOS patch against the exact audited LineageOS base revision.
With --match-worktrees, also checks that applying each patch recreates the
corresponding files in the current LineageOS workspace exactly.
EOF
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --match-worktrees)
            match_worktrees=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            usage
            fail "unknown argument: $1"
            ;;
        *)
            [[ -z "$lineage_root" ]] || fail "only one LineageOS root is accepted"
            lineage_root="$1"
            shift
            ;;
    esac
done

[[ -n "$lineage_root" ]] || { usage; exit 2; }
lineage_root="$(cd "$lineage_root" && pwd)"

expected_patches=(
    0001-cmi-device-webcam.patch
    0002-frameworks-base-webcam-default.patch
    0003-device-as-webcam-uvc.patch
    0004-sm8250-uvc-gadget.patch
    0005-system-server-uvc-sepolicy.patch
    0006-vendor-qcom-usb-uvc-rates.patch
    0007-settings-wireless-debugging-persistence.patch
    0008-adbd-uvc-only-cable.patch
    0009-lineage-cacamos-appliance.patch
    0010-build-make-cacamos-appliance.patch
    0011-recovery-cacamos-adb.patch
    0012-system-core-cacamos-boot-probe.patch
    0013-build-soong-resource-limits.patch
    0014-build-blueprint-resource-limits.patch
)
mapfile -t actual_patches < <(
    find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort
)
[[ "${actual_patches[*]}" == "${expected_patches[*]}" ]] ||
    fail "unexpected patch set: ${actual_patches[*]}"

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/cacamos-patch-series.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT
patch_number=0

verify_patch() {
    local project="$1"
    local base_revision="$2"
    local strip_components="$3"
    local patch_name="$4"
    local repository="$lineage_root/$project"
    local patch_path="$patch_dir/$patch_name"
    local temporary_index="$temporary_dir/index-$patch_number"
    local additions deletions path
    local -a touched_paths=()

    [[ -d "$repository/.git" ]] || fail "missing Git repository: $repository"
    [[ -f "$patch_path" ]] || fail "missing patch: $patch_path"
    git -C "$repository" cat-file -e "$base_revision^{commit}" 2>/dev/null ||
        fail "$project lacks audited base $base_revision"

    GIT_INDEX_FILE="$temporary_index" \
        git -C "$repository" read-tree "$base_revision"
    GIT_INDEX_FILE="$temporary_index" \
        git -C "$repository" apply --cached --check \
            -p"$strip_components" "$patch_path"
    GIT_INDEX_FILE="$temporary_index" \
        git -C "$repository" apply --cached \
            -p"$strip_components" "$patch_path"

    if [[ "$match_worktrees" -eq 1 ]]; then
        while IFS=$'\t' read -r additions deletions path; do
            [[ -n "$path" ]] && touched_paths+=("$path")
        done < <(git apply --numstat -p"$strip_components" "$patch_path")
        [[ "${#touched_paths[@]}" -gt 0 ]] ||
            fail "$patch_name does not modify any file"
        GIT_INDEX_FILE="$temporary_index" \
            git -C "$repository" diff --quiet -- "${touched_paths[@]}" ||
            fail "$patch_name does not match the current $project worktree"
    fi

    printf 'OK: %s at %s\n' "$patch_name" "$base_revision"
    patch_number=$((patch_number + 1))
}

verify_patch device/xiaomi/cmi 7f75e59ee89061db953552993b674ca0524f7c2a 4 \
    0001-cmi-device-webcam.patch
verify_patch frameworks/base 58e0f87dbbc8e379ba41a1b1c001911ff948ecd3 3 \
    0002-frameworks-base-webcam-default.patch
verify_patch packages/services/DeviceAsWebcam d255c45cb59f5b9e1d670ed716afce8bd3b7d909 4 \
    0003-device-as-webcam-uvc.patch
verify_patch kernel/xiaomi/sm8250 71b13e62f057a649b77fe4062feb73ee72ad609c 4 \
    0004-sm8250-uvc-gadget.patch
verify_patch system/sepolicy 885cc500f6078a766d1f6def5ce4c06c55841773 3 \
    0005-system-server-uvc-sepolicy.patch
verify_patch vendor/qcom/opensource/usb 9b4843b6e82832cca985026e590f6a5fd2d50705 5 \
    0006-vendor-qcom-usb-uvc-rates.patch
verify_patch packages/apps/Settings e7aabad461b920842bad5bac80b29013d4d7aae9 4 \
    0007-settings-wireless-debugging-persistence.patch
verify_patch packages/modules/adb 262cc9ada912c17f30f3130ae22e8012be4e10fe 4 \
    0008-adbd-uvc-only-cable.patch
verify_patch vendor/lineage d748482bfadd2101f420b8120469479ecb970d75 3 \
    0009-lineage-cacamos-appliance.patch
verify_patch build/make 10a1fcb5ef113daeeeb36efecec789e473663843 3 \
    0010-build-make-cacamos-appliance.patch
verify_patch bootable/recovery d4ef5569dda1c5066f90efd25455b589ced6073e 3 \
    0011-recovery-cacamos-adb.patch
verify_patch system/core e99d3d82bd3dac2df72cb741e1067b19c38e87c6 3 \
    0012-system-core-cacamos-boot-probe.patch
verify_patch build/soong 4035bec90f84b583a1502b9a546c6117a28fdbe2 3 \
    0013-build-soong-resource-limits.patch
verify_patch build/blueprint c39c8a4c103f1393f015a5befa7726f0c14c9bc2 3 \
    0014-build-blueprint-resource-limits.patch

printf '\nPASS: CaCamOS patch series is reproducible from the audited bases.\n'
