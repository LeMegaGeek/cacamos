#!/usr/bin/env bash
set -euo pipefail

lineage_root=""
target="bacon"
jobs=1
check_only=0
allow_low_memory=0
reserve_cores=2
cpu_set=""
cpu_set_cores=0
min_free_mem_mib=3072
watchdog_interval_seconds=15
go_memlimit_mib=24000

usage() {
    cat >&2 <<'EOF'
Usage:
  build-lineage-gentle.sh --lineage-root /path/to/lineageos [--target bacon]
  build-lineage-gentle.sh --lineage-root /path/to/lineageos --check-only

Runs the MI8 LineageOS build with controlled resource limits:
  - configurable build jobs, default 1
  - GOMAXPROCS follows the job count
  - two CPU cores reserved for the desktop when taskset is available
  - low CPU and IO priority
  - memory/swap preflight before starting
  - memory watchdog while the build is running

This script is intentionally slow. It exists to keep the desktop usable.

Options:
  --jobs N            Build parallelism. Default: 1
  --reserve-cores N   Keep N CPU cores free for the desktop. Default: 2
  --cpu-set LIST      Use an explicit taskset CPU list, for example 0-3
  --min-free-mem-mib N
                      Stop the build if MemAvailable drops below N MiB.
                      Default: 3072
  --go-memlimit-mib N
                      GOMEMLIMIT for Soong/Go processes. Default: 24000
  --watchdog-interval N
                      Memory watchdog polling interval in seconds. Default: 15
  --allow-low-memory  Skip the memory/swap safety stop
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

mem_kib() {
    awk -v key="$1" '$1 == key ":" { print $2 }' /proc/meminfo
}

is_non_negative_integer() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

is_positive_integer() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lineage-root)
            lineage_root="${2:-}"
            shift 2
            ;;
        --target)
            target="${2:-}"
            shift 2
            ;;
        --jobs)
            jobs="${2:-}"
            is_positive_integer "$jobs" ||
                fail "--jobs expects a positive integer"
            shift 2
            ;;
        --check-only)
            check_only=1
            shift
            ;;
        --allow-low-memory)
            allow_low_memory=1
            shift
            ;;
        --reserve-cores)
            reserve_cores="${2:-}"
            is_non_negative_integer "$reserve_cores" ||
                fail "--reserve-cores expects a non-negative integer"
            shift 2
            ;;
        --cpu-set)
            cpu_set="${2:-}"
            [[ -n "$cpu_set" ]] || fail "--cpu-set expects a CPU list"
            shift 2
            ;;
        --min-free-mem-mib)
            min_free_mem_mib="${2:-}"
            is_positive_integer "$min_free_mem_mib" ||
                fail "--min-free-mem-mib expects a positive integer"
            shift 2
            ;;
        --watchdog-interval)
            watchdog_interval_seconds="${2:-}"
            is_positive_integer "$watchdog_interval_seconds" ||
                fail "--watchdog-interval expects a positive integer"
            shift 2
            ;;
        --go-memlimit-mib)
            go_memlimit_mib="${2:-}"
            is_positive_integer "$go_memlimit_mib" ||
                fail "--go-memlimit-mib expects a positive integer"
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
lineage_root="$(cd "$lineage_root" && pwd)"
[[ -f "$lineage_root/build/envsetup.sh" ]] || fail "missing build/envsetup.sh in $lineage_root"
[[ -d "$lineage_root/device/xiaomi/dipper" ]] || fail "missing device/xiaomi/dipper"

mem_available_kib="$(mem_kib MemAvailable)"
swap_free_kib="$(mem_kib SwapFree)"
load_1min="$(awk '{ print $1 }' /proc/loadavg)"
cpu_count="$(getconf _NPROCESSORS_ONLN)"
if (( cpu_count < 1 )); then
    fail "cannot detect online CPU count"
fi

if [[ -z "$cpu_set" ]]; then
    if (( cpu_count > reserve_cores )); then
        last_cpu=$((cpu_count - reserve_cores - 1))
    else
        last_cpu=$((cpu_count - 1))
    fi

    if (( last_cpu < 0 )); then
        last_cpu=0
    fi

    if (( last_cpu == 0 )); then
        cpu_set="0"
    else
        cpu_set="0-${last_cpu}"
    fi
fi

count_cpu_set_cores() {
    local list="$1"
    local field part count start end
    count=0

    IFS=',' read -r -a fields <<< "$list"
    for part in "${fields[@]}"; do
        if [[ "$part" == *-* ]]; then
            start="${part%-*}"
            end="${part#*-}"
            if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$start" -le "$end" ]]; then
                count=$((count + end - start + 1))
            else
                count=0
                break
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            count=$((count + 1))
        else
            count=0
            break
        fi
    done

    if (( count <= 0 )); then
        count="$cpu_count"
    fi
    printf '%d' "$count"
}

cpu_set_cores="$(count_cpu_set_cores "$cpu_set")"
if (( cpu_set_cores > cpu_count )); then
    cpu_set_cores="$cpu_count"
fi
if (( cpu_set_cores < 1 )); then
    cpu_set_cores=1
fi
if (( jobs > cpu_set_cores )); then
    printf 'NOTICE: %s\n' "Reducing build jobs from $jobs to $cpu_set_cores to stay within reserved cores."
    jobs="$cpu_set_cores"
fi

printf 'Host resource preflight:\n'
printf '  MemAvailable: %d MiB\n' "$((mem_available_kib / 1024))"
printf '  SwapFree:      %d MiB\n' "$((swap_free_kib / 1024))"
printf '  Load 1 min:    %s\n' "$load_1min"
printf '  CPUs online:   %s\n' "$cpu_count"
printf '  Build jobs:    %s\n' "$jobs"
printf '  Reserve cores: %s\n' "$reserve_cores"
printf '  Go mem limit:  %s MiB\n' "$go_memlimit_mib"
printf '  Watchdog stop: %s MiB MemAvailable\n' "$min_free_mem_mib"
printf '  Watchdog tick: %s seconds\n' "$watchdog_interval_seconds"
if command -v taskset >/dev/null 2>&1; then
    printf '  Build CPU set: %s\n' "${cpu_set:-all}"
else
    printf '  Build CPU set: unavailable, taskset not found\n'
fi

if [[ "$allow_low_memory" -ne 1 ]]; then
    (( mem_available_kib >= 8 * 1024 * 1024 )) ||
        fail "MemAvailable is below 8192 MiB; close applications or rerun with --allow-low-memory"
    (( swap_free_kib >= 1024 * 1024 )) ||
        fail "SwapFree is below 1024 MiB; close applications or rerun with --allow-low-memory"
fi

if [[ "$check_only" -eq 1 ]]; then
    printf '\nPreflight only: build not started.\n'
    exit 0
fi

printf '\nStarting conservative MI8 build target: %s\n' "$target"
printf 'This can still take hours. Stop with Ctrl+C if the desktop becomes uncomfortable.\n\n'

cd "$lineage_root"
export GOMAXPROCS=1
export GOMAXPROCS="$jobs"
export GOMEMLIMIT="${go_memlimit_mib}MiB"
export NINJA_ARGS="-j${jobs}"
export CACAM_BUILD_TARGET="$target"
export CACAM_BUILD_JOBS="$jobs"

run_build() {
    set -e
    # shellcheck disable=SC1091
    source build/envsetup.sh
    breakfast dipper
    m -j"$CACAM_BUILD_JOBS" "$CACAM_BUILD_TARGET"
}

if command -v ionice >/dev/null 2>&1; then
    runner=(nice -n 15 ionice -c3)
else
    runner=(nice -n 15)
fi

if [[ -n "$cpu_set" ]] && command -v taskset >/dev/null 2>&1; then
    runner+=(taskset -c "$cpu_set")
fi

build_pid=""
watchdog_pid=""

stop_build() {
    local signal="${1:-TERM}"

    if [[ -n "$watchdog_pid" ]] && kill -0 "$watchdog_pid" 2>/dev/null; then
        kill "$watchdog_pid" 2>/dev/null || true
    fi

    if [[ -n "$build_pid" ]] && kill -0 "$build_pid" 2>/dev/null; then
        kill "-$signal" -- "-$build_pid" 2>/dev/null || true
        kill "-$signal" "$build_pid" 2>/dev/null || true
    fi
}

trap 'printf "\nInterrupted, stopping build...\n" >&2; stop_build TERM; exit 130' INT TERM

build_command=("${runner[@]}" bash -lc "$(declare -f run_build); run_build")

if command -v setsid >/dev/null 2>&1; then
    setsid "${build_command[@]}" &
else
    "${build_command[@]}" &
fi
build_pid="$!"

(
    while kill -0 "$build_pid" 2>/dev/null; do
        sleep "$watchdog_interval_seconds"
        current_mem_available_kib="$(mem_kib MemAvailable)"
        if (( current_mem_available_kib < min_free_mem_mib * 1024 )); then
            printf '\nERROR: MemAvailable dropped below %d MiB; stopping build to keep the desktop usable.\n' \
                "$min_free_mem_mib" >&2
            kill -TERM -- "-$build_pid" 2>/dev/null || true
            kill "$build_pid" 2>/dev/null || true
            exit 0
        fi
    done
) &
watchdog_pid="$!"

set +e
wait "$build_pid"
build_status="$?"
set -e

if [[ -n "$watchdog_pid" ]] && kill -0 "$watchdog_pid" 2>/dev/null; then
    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
fi

exit "$build_status"
