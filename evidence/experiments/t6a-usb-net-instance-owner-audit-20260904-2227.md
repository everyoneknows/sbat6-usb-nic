# T6A usb_net ConfigFS instance-owner audit — 2026-09-04

## Scope

Path: `agent-101-vm -> raspi2 -> root@T6A-MGMT-IP`.
Read-only inventory and trace setup preceded the requested destructive phase.
ACM, FFS, and mass-storage instances were never removed.

## Pre-change inventory

Kernel: Linux 5.4.238 aarch64. Vendor module:
`usb_net 77824 6`, `/lib/modules/5.4.238/usb_net.ko`.

ConfigFS instances:

```
acm.gs0
acm.gs1
acm.gs2
ecm.gs8
ffs.adb
mass_storage.usb0
ncm.gs8
rndis.gs4
```

The vendor module's `modinfo` aliases were exactly:

```
usbfunc:rndis
usbfunc:ecm
usbfunc:ncm
```

Therefore the provider-owned instances were classified as `ncm.gs8`,
`ecm.gs8`, and `rndis.gs4`. The other five instances were excluded.

Pre-change live state was `UDC=11201000.usb`, `current_speed=super-speed`,
`ncm0 UP/LOWER_UP`, and `192.168.77.1/24`.

## Trace and refcount evidence

Tracepoint `module:module_get` and `module:module_put` were available. A
dedicated trace instance was created at:

```
/sys/kernel/debug/tracing/instances/butlerx-usb-net-audit-20260904-222300
```

Snapshot:

```
/tmp/butlerx-usb-net-audit-20260904-222300
```

After UDC unbind and unlinking only `f1`–`f5`, refcount remained 6.

| operation | result | refcount | trace |
|---|---:|---:|---|
| `ncm.gs8` rmdir | 0 | 6 -> 4 | `usb_put_function_instance` at 6; `configfs_rmdir` at 5 |
| `ecm.gs8` rmdir | 0 | 4 -> 2 | `usb_put_function_instance` at 4; `configfs_rmdir` at 3 |
| `rndis.gs4` rmdir | 0 | 2 -> 0 | `usb_put_function_instance` at 2; `configfs_rmdir` at 1 |

This measured `refcount 6 = 3 provider instances x 2 module_puts per rmdir`
for this vendor implementation. No D-state occurred during these three
provider removals. Normal `rmmod usb_net` then succeeded with return code 0.

## Candidate phase

Verified SHA256 and loaded successfully:

```
sbat6_ncm_telemetry.ko  94b157ad17cbe678f2484d058b2e5f8231e5ed6de6fe33f8349ee1588ca6ebf5
usb_f_ncm.ko            d2257ff360fa82c6f2ea639a9856ebd5db7e018b1e71c1113eb74e48ffe7e783
```

`insmod` for both modules returned 0. `usb_f_ncm` showed dependency on
`sbat6_ncm_telemetry`; the sink was marked permanent by the module itself.

The candidate `mkdir /config/usb_gadget/g1/functions/ncm.gs8` returned 0, but
the new instance exposed no regular attributes and no `ncm0` netdev. The
relative `f5` symlink attempt returned ENOENT. An absolute symlink attempt
then stopped responding; the SSH session timed out. A fresh connection from
raspi2 subsequently got `No route to host`, ping had 100% loss, and ARP was
`FAILED`.

## Status and limits

The target became unreachable during candidate ConfigFS reconstruction. No
UDC bind, Windows re-enumeration, SuperSpeed verification, ping, iperf, or
telemetry measurement was performed after candidate load. No force-rmmod was
used. Normal reboot/recovery could not be initiated because the management
path was lost.

The pre-change snapshot and existing rollback script remain available for
recovery after T6A management access returns.
