# T6A vendor CDC-NCM enablement — 2026-09-03

## BEFORE snapshot

Primary snapshot was retained on T6A as `/tmp/butlerx-t6a-ncm-20260903-before/`.
It contains the vendor script, `/etc/config/usb`, ConfigFS listings/attributes,
UDC state, interface list, and dmesg. The relevant observed state was:

- FACT: T6A is Linux 5.4.238 aarch64, OpenWrt 21.02.7.
- FACT: `g1/UDC=11201000.usb`; UDC state was `not attached`.
- FACT: `configs/b.1/f1..f4` were ACM/ADB/ACM/ACM and were preserved.
- FACT: `ncm.gs8` and `ncm.usb0` existed; both `ifname=(unnamed net_device)`.
- FACT: no USB network interface was present in `ip -br link`.
- FACT: device MAC configured for `ncm.gs8` was `02:00:00:00:00:03`.

## Vendor provenance

FACT: `/etc/init.d/usb.init` creates `rndis.gs4`, `ecm.gs8`, `ncm.gs8`,
and the ACM/ADB/storage functions. In the normal `mipcboot=0` branch it links
`rndis.gs4` as `f1`, then ADB/ACM as `f2..f4`; the ECM and NCM link commands
are present but commented out. The same source is visible through
`/etc/rc.d/S30usb.init`. `/etc/config/usb` selects VID `0x2c7c`, PID `0x7006`.

INFERENCE: `ncm.gs8` is a vendor-precreated optional function, deliberately
left out of the normal product configuration. Its existence is not evidence
that it was meant to be active at boot.

## Implementation evidence

FACT: the saved T6A-compatible `f_ncm.c` calls `gether_setup_default()` in
`ncm_alloc_inst()` (instance creation), but calls `gether_set_gadget()` and
`gether_register_netdev()` in `ncm_bind()` (composite bind). The latter calls
`register_netdev()`. Therefore this implementation registers the net_device
when the linked function is bound to the UDC, not merely when the ConfigFS
directory is created and not only after host enumeration.

## ACTION

1. Created and retained the BEFORE snapshot above.
2. Added only `configs/b.1/f5 -> /config/usb_gadget/g1/functions/ncm.gs8`.
   The first relative-link attempt failed and made no change; the absolute
   link succeeded.
3. Unbound and rebound the existing UDC once (`UDC=''`, then
   `UDC=11201000.usb`) so the newly linked function was bound. No mode,
   role-switch, VBUS, GPIO, register, DT, flash, bootloader, IP, bridge,
   NAT, Wi-Fi, LTE, or LAN setting was written. No reboot was performed.

## AFTER snapshot / physical observation

Primary AFTER snapshot was retained on T6A as
`/tmp/butlerx-t6a-ncm-20260903-after/`.

- FACT: `ncm.gs8/ifname` became `ncm0`.
- FACT: `ncm0` appeared as `DOWN`, MAC `02:00:00:00:00:03`.
- FACT: UDC remained `function=g1`, `state=not attached`.
- FACT: `f1..f4` remained unchanged; `f5` is the only ConfigFS link added.
- FACT: `eth0`, `br-lan`, Wi-Fi interfaces, and `ccmni*` remained present;
  existing route entries remained `172.16.255.0/24` and `192.168.3.0/24`.
- FACT: after snapshot observed `/sys/devices/platform/11201000.usb/mode=2`;
  this agent did not write that node. The earlier value immediately before
  this experiment was not captured, so mode continuity is UNKNOWN.
- UNKNOWN: host-side VBUS, host enumeration, and NCM packet communication.

## Verdict

FACT: the requested T6A-side NCM net_device appearance succeeded.
FACT: this is not a USB host-enumeration or communication success claim.
The experiment stopped at the requested net_device condition.

## Rollback

On T6A, while no host is attached: remove only
`/config/usb_gadget/g1/configs/b.1/f5`, then unbind/rebind `g1` using the
same UDC value `11201000.usb`. This restores the pre-experiment function
links while leaving `f1..f4` untouched. The retained BEFORE snapshot is the
rollback reference. Do not run `/etc/init.d/usb.init restart`, because its
normal stop path removes all `f*` links.

## End summary

- confirmed facts: vendor origin, intentional NCM omission, bind-time
  registration, `ncm0` creation, MAC, f1..f4 preservation.
- disproved hypotheses: ConfigFS directory creation alone registers the netdev;
  host enumeration is required for the observed T6A-side registration.
- unresolved questions: host VBUS/enumeration and actual NCM traffic.
- next safest experiment: a separately planned physical host-enumeration test
  with VBUS and host-side USB evidence recorded first; no such test was done.

> Privacy note (2026-09-06): personal paths, management addresses and device MACs in this document are redacted or replaced with examples; they are not original measured identifiers.
