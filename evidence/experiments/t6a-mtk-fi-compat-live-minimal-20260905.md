# T6A MTK function-instance ABI live validation — 2026-09-05

## Scope

Only the one-time ConfigFS instance creation test was performed. The path was
`agent-101-vm -> raspi2 -> LAN/SSH -> root@192.168.3.2`. ADB, the forbidden
`sbat6_usb_role_runtime2.ko`, UDC bind/rebind, `f5` linking, Windows, network,
performance, GPIO, role, and mode operations were not performed.

## Management precheck

- SSH succeeded through raspi2; target was identified as the T6A.
- Pre-test uptime: `up 1:16`.
- Pre-test `usb_net`: `77824 6`.
- Vendor function directories existed and were unlinked: `ncm.gs8`, `ecm.gs8`,
  `rndis.gs4`.
- Pre-test UDC field: `11201000.usb`; state: `not attached`; speed:
  `super-speed`.
- Pre-test pstore: one `console-ramoops-0`, 262132 bytes.
- `dmesg` and `logread` were readable.

## Artifacts

- Candidate `usb_f_ncm-extended.ko` SHA256:
  `1fb49fd6cf347e2676327d92a22808ee0d767792dcbc52261d2d41b81b0afc06`
- Telemetry `sbat6_ncm_telemetry.ko` SHA256:
  `94b157ad17cbe678f2484d058b2e5f8231e5ed6de6fe33f8349ee1588ca6ebf5`
- Both hashes matched on T6A after transfer.

## Module sequence

Vendor-only release succeeded:

```text
ncm.gs8   rmdir RC=0; usb_net 6 -> 4
ecm.gs8   rmdir RC=0; usb_net 4 -> 2
rndis.gs4 rmdir RC=0; usb_net 2 -> 0
rmmod usb_net RC=0
```

Telemetry load succeeded: `insmod RC=0`. Candidate load succeeded:
`insmod RC=0`.

Immediately after candidate load:

```text
usb_f_ncm              36864  0 [permanent]
sbat6_ncm_telemetry    20480  1 usb_f_ncm,[permanent]
uptime                 up 1:18
```

## Minimal ConfigFS test

Exactly one creation was attempted:

```text
mkdir /config/usb_gadget/g1/functions/ncm.gs8
MKDIR_RC=0
```

Immediate listing contained normal attributes, not directory-only output:

```text
dev_addr  present
host_addr  present
qmult      present
ifname     present
```

Attribute reads all completed successfully:

```text
ifname    = (unnamed net_device)
qmult     = 5
dev_addr  = 02:00:00:00:00:04
host_addr = 02:00:00:00:00:05
```

SSH remained usable throughout the test. No Oops or candidate-related kernel
warning appeared. Existing unrelated T6A GNSS/Wi-Fi/USB warnings continued in
the log.

## Cleanup and restoration

The test instance was removed: `rmdir RC=0`. Candidate and telemetry normal
`rmmod` both returned `255` because these modules are marked `[permanent]`;
force removal was not attempted.

Because the permanent candidate prevented the vendor module from being loaded
(`usb_net: exports duplicate symbol gether_cleanup`), one normal reboot was
required for the vendor boot initialization to restore the prior state. SSH
recovered through raspi2 after approximately one minute.

Final state:

```text
usb_net                 77824  6
usb_f_ncm               absent
sbat6_ncm_telemetry     absent
ncm.gs8                 present
ecm.gs8                 present
rndis.gs4               present
f1..f4                  present (unchanged)
f5                      absent
UDC field               11201000.usb
UDC state               not attached
```

Pstore remained a single `console-ramoops-0`; the post-reboot image was
collected at
`evidence/pstore/20260905/live-minimal-20260905/console-ramoops-0`.
Its SHA256 is recorded alongside it. No additional pstore filename appeared.

## Classification

```text
CONFIGFS_INSTANCE_CREATE=PASS
MTK_FUNCTION_INSTANCE_COMPAT=LIVE_CONFIRMED
```

This confirms ConfigFS function-instance ABI compatibility only. It is not a
driver functional network test. The next controlled ConfigFS link / UDC
functional test remains out of scope.

