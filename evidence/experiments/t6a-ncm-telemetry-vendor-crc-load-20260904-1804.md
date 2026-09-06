# T6A NCM telemetry vendor-CRC load smoke test — 2026-09-04 18:04 JST

## Scope and path

The target was accessed only through `agent-101-vm -> raspi2 -> T6A` using
LAN/SSH and the configured SSH identity. ADB was not used. No USB
role, UDC binding, ConfigFS value, netdev, IP address, reboot, or persistent
file was changed.

## Failure found and corrected

The earlier artifact was built against the ax88179 output `Module.symvers`.
Although its vermagic matched `5.4.238 SMP mod_unload modversions aarch64`,
T6A rejected it with:

```text
sbat6_ncm_telemetry: disagrees about version of symbol module_layout
```

The Makefile was corrected to build against the saved vendor tree
`/home/user/projects/sbair6-rce/work/src/linux-5.4.238`, whose vendor
`Module.symvers` contains the target CRC set.

## Exact rebuild

```text
make clean && make V=1                         PASS
local SHA256: 8b069108fbdb0ee7e751986a412f0f08c88e24b095d4b89f680d5bdf50691e68
target SHA256: 8b069108fbdb0ee7e751986a412f0f08c88e24b095d4b89f680d5bdf50691e68
arch: aarch64
release: 5.4.238
```

## Target smoke test

The corrected module was copied to `/tmp` and loaded with `insmod`.

```text
INSMOD_RC=0
debugfs stats readable: yes
all counters: 0 (expected; this is the unintegrated counter sink)
rmmod RC=0
debugfs directory removed: yes
ncm0: UP, LOWER_UP
UDC: configured
```

The load path created only the telemetry debugfs directory. The module has no
USB, UDC, ConfigFS, role, netdev, timer, worker, kprobe, or ftrace hook.

## Current live limitation

At the same observation time, raspi4 had no `usb0` and no CDC-NCM host link;
therefore no iperf3 run or telemetry interval was started. The T6A management
SSH path remained healthy. No throughput number is claimed from this smoke
test.

## Decision

The standalone telemetry ABI/load/unload path is now target-compatible and
reversible. It is not yet an end-to-end measurement. The next useful live
step requires the existing Windows/raspi4 USB cable link, after which the
source-integrated vendor path must be tested with one change at a time.

> Privacy note (2026-09-06): personal paths, management addresses and device MACs in this document are redacted or replaced with examples; they are not original measured identifiers.
