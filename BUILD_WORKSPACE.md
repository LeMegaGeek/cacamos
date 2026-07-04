# Building CaCam OS LineageOS Workspaces

The CaCam OS source addons need a synced LineageOS tree before a flashable ROM
can be produced.

Supported targets:

```text
cmi     Xiaomi Mi 10 Pro  LineageOS lineage-23.2
dipper  Xiaomi Mi 8       LineageOS lineage-22.2
```

Check the current host and print the exact next commands:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Install the `repo` launcher without root if it is missing:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --install-repo dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Initialize the workspace:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --init dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Write the local manifest for the device tree, common tree, kernel and vendor
blobs before syncing:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --local-manifest dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

Full sync is large and can take hours:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --sync dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

`--sync` also writes the local manifest automatically after `repo init`.

For a faster source-only webcam preflight, sync only the projects needed by the
addon verifier:

```bash
./cacam-os/tools/prepare-lineage-workspace.sh --sync-webcam-deps dipper /home/denis/Documents/Denis/dev/lineage-dipper
```

This is useful before applying the patch, but it is not enough for `mka bacon`.
The full ROM build still requires the complete LineageOS sync.

After sync, apply the device addon:

```bash
./cacam-os/lineageos/dipper/tools/install-into-lineage.sh /home/denis/Documents/Denis/dev/lineage-dipper
```

Then build:

```bash
./cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --check-only

./cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper
```

For Denis' current desktop, do not start with the normal `mka bacon` command.
Use the MI8 gentle wrapper first: it keeps one build job, reserves two CPU cores
when `taskset` is available, lowers CPU/IO priority, checks memory/swap before
starting, and stops the build if available memory falls below the configured
watchdog threshold.

Useful stricter form for the first resumed build:

```bash
./cacam-os/lineageos/dipper/tools/build-lineage-gentle.sh \
  --lineage-root /home/denis/Documents/Denis/dev/lineage-dipper \
  --min-free-mem-mib 4096
```

## Connected Device Audit

Before flashing or rebuilding, collect a read-only ADB/host report:

```bash
./cacam-os/tools/audit-connected-device.sh
```

The report is written under:

```text
dist/cacam-os-audits/
```
