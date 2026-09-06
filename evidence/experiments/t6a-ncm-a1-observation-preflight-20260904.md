# T6A NCM A班 observation candidate preflight — 2026-09-04

## Current hardware gate

The only management path used was `agent-101-vm -> raspi2 -> LAN/SSH ->
root@192.168.3.2`. ADB, runtime2, role changes, flash, reboot, and persistent
configuration changes were not used.

At the observation time the T6A state was:

- management path healthy;
- `usb_net` loaded and `usb_f_ncm` absent;
- `f5 -> ncm.gs8` present;
- `UDC=11201000.usb`, state `not attached`;
- `ncm0` present with `192.168.77.1/24`, administratively UP but `NO-CARRIER`;
- carrier and all four error/drop counters were zero.

The Windows host/VBUS was not attached, so the required baseline and any
iperf measurement are not yet executable. No throughput or experiment result
is claimed.

## Static candidate work

The existing source candidate in `/home/user/projects/sbat6-usbnet/source/`
was rebuilt after adding the missing RX completion call at the exact
`rx_complete()` entry point. It remains a plain-value, no-allocation telemetry
call and does not alter request or skb lifetime.

The candidate was first found to have an invalid dependency set when built
against the vendor aggregate `Module.symvers`: modpost assigned ordinary
kernel symbols to `usb_net.ko`, producing a candidate that depended on the
provider it was intended to replace. This was rejected.

The corrected build uses the T6A kernel-image symbol map plus the telemetry
sink map. Result:

- build: PASS;
- vermagic: `5.4.238 SMP mod_unload modversions aarch64`;
- module dependency: `sbat6_ncm_telemetry` only;
- RX completion symbol imported with the telemetry sink CRC;
- artifact SHA-256: `d2257ff360fa82c6f2ea639a9856ebd5db7e018b1e71c1113eb74e48ffe7e783`.

The candidate was not copied to or loaded on T6A.

## Guard change

`tools/t6a-replace-telemetry.sh` now saves a timestamped `/tmp` snapshot
before any provider removal: the ConfigFS tree, regular attributes,
`f1`–`f5` link targets, UDC, NCM MAC/qmult values, and `ncm0` state. It uses
an absolute target with `readlink -f` verification and restores all saved NCM
attributes during rollback. Shell syntax validation passed.

## Decision

`INCONCLUSIVE` — observation candidate preflight is complete, but live
baseline is blocked by the absent Windows USB host/VBUS connection.

Reverted: YES (no live candidate change was made)
Confidence: HIGH for the static dependency finding; LOW for performance.

Next gate: connect the intended Windows Pavilion USB host/VBUS, then verify
UDC `configured`, carrier, Windows `UsbNcm Host Device`, `192.168.77.2/24`,
bidirectional ping, and the three-run baseline before any candidate load.

> Privacy note (2026-09-06): personal paths, management addresses and device MACs in this document are redacted or replaced with examples; they are not original measured identifiers.
