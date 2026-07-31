#!/usr/bin/env bash
set -euo pipefail

required_commands=(
    git
    git-lfs
    curl
    python3
    java
    javac
    make
    ninja
    zip
    unzip
    bc
    repo
    ccache
    bison
    flex
    lz4
    brotli
)

missing=0

printf 'CaCam OS cmi build host check\n\n'

for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf 'OK   %s -> %s\n' "$cmd" "$(command -v "$cmd")"
    else
        printf 'MISS %s\n' "$cmd"
        missing=1
    fi
done

printf '\nJava:\n'
java -version 2>&1 | sed 's/^/  /' || true

printf '\nMemory:\n'
free -h | sed 's/^/  /'

printf '\nDisk:\n'
df -h . | sed 's/^/  /'

if [[ -f build/envsetup.sh && -d .repo ]]; then
    printf '\nOK   current directory looks like an Android/LineageOS tree\n'
elif [[ -d .repo ]]; then
    printf '\nWARN .repo exists, but build/envsetup.sh is missing here\n'
    missing=1
else
    printf '\nMISS current directory is not a synced LineageOS tree\n'
    missing=1
fi

exit "$missing"
