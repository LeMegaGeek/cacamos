# Build Requirements for CaCamOS `cmi`

Qualified host profile on 2026-07-31:

- 16 logical CPU cores;
- 29 GiB RAM;
- 81 GiB permanent swap;
- at least 300 GiB free disk space;
- OpenJDK 21 and the standard LineageOS 23.2 build dependencies;
- a complete synchronized `lineage_cmi-bp4a-userdebug` source tree.

The supported controlled build profile uses ten workers, reserves six cores and
sets a Go memory ceiling:

```bash
./lineageos/cmi/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-cmi \
  --target bacon \
  --jobs 10 \
  --cpu-set 0-9 \
  --reserve-cores 6 \
  --go-memlimit-mib 18432 \
  --min-free-mem-mib 5120 \
  --min-free-swap-mib 32768
```

Before building, run:

```bash
./lineageos/cmi/tools/check-build-host.sh
./lineageos/cmi/tools/check-lineage-source-preflight.sh \
  /home/denis/Documents/Denis/dev/lineage-cmi
```

Do not bypass the wrapper's memory watchdog or consume all sixteen cores. The
profile is intentionally faster than the old small-PC build while retaining
desktop and memory headroom.
