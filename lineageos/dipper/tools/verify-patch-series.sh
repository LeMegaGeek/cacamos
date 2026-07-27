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
    0001-dipper-device-webcam.patch
    0002-frameworks-base-webcam-default.patch
    0003-device-as-webcam-uvc.patch
    0004-sdm845-uvc-gadget.patch
    0005-system-server-uvc-sepolicy.patch
    0006-vendor-qcom-usb-uvc-rates.patch
    0007-settings-wireless-debugging-persistence.patch
    0008-adbd-uvc-only-cable.patch
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

verify_patch device/xiaomi/dipper 77d5976 4 \
    0001-dipper-device-webcam.patch
verify_patch frameworks/base ff7620a38e54 3 \
    0002-frameworks-base-webcam-default.patch
verify_patch packages/services/DeviceAsWebcam 277855b 4 \
    0003-device-as-webcam-uvc.patch
verify_patch kernel/xiaomi/sdm845 aa8adfe9bf21 4 \
    0004-sdm845-uvc-gadget.patch
verify_patch system/sepolicy 24428bf86 3 \
    0005-system-server-uvc-sepolicy.patch
verify_patch vendor/qcom/opensource/usb 0366694 5 \
    0006-vendor-qcom-usb-uvc-rates.patch
verify_patch packages/apps/Settings 0f0669fc699 4 \
    0007-settings-wireless-debugging-persistence.patch
verify_patch packages/modules/adb 741291b810d7 4 \
    0008-adbd-uvc-only-cable.patch

printf '\nPASS: CaCamOS patch series is reproducible from the audited bases.\n'
