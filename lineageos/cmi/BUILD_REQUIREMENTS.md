# Build Requirements for CaCam OS `cmi`

To finish the ROM path, we need a complete LineageOS `lineage-23.2` build tree
for Xiaomi Mi 10 Pro (`cmi`) and enough host tooling to run a full Android
build.

## Current Host Audit

Audit date: 2026-06-30

Available:

- Disk space: about 963 GiB free on `/`
- CPU: 4 logical cores
- RAM: about 11 GiB
- Java: OpenJDK 21
- Basic tools: `git`, `curl`, `python3`, `make`, `ninja`, `zip`, `unzip`, `bc`

Missing or not detected:

- `repo`
- `ccache`
- common Android build tools such as `bison`, `flex`, `lz4`, `brotli`
- an existing LineageOS checkout

## Practical Impact

The CaCam OS source addon is ready, but the final ROM proof still requires:

1. A synced LineageOS `lineage-23.2` tree with `device/xiaomi/cmi`.
2. The addon applied with `tools/install-into-lineage.sh`.
3. A successful `mka bacon`.
4. Flashing the resulting build on the Mi 10 Pro.
5. Host-side webcam verification in OBS or `v4l2-ctl`.

The current machine has enough disk, but the missing build tools and limited RAM
make a full local build uncertain without preparing the host first.
