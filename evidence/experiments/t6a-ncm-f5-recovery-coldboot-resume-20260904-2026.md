# T6A USB NCM f5 recovery — cold-boot resume — 2026-09-04 20:26 JST

## Scope and access

This resume used only `agent-101-vm -> raspi2 -> LAN/SSH -> root@T6A-MGMT-IP`.
ADB, USB role changes, flash, reboot, and persistent device configuration were
not used. The procedure was reproduced from
`t6a-ncm-f5-recovery-20260904.md` and `tools/t6a-ncm-recover-f5.sh`.

## Pre-recovery live state

- `br-lan`: `UP`, `T6A-MGMT-IP/24` (management path healthy).
- `g1/UDC`: `11201000.usb`; UDC state: `not attached`.
- `functions/ncm.gs8`: present; `ifname`: `(unnamed net_device)`.
- `configs/b.1/f5`: absent; `ncm0`: absent.
- `usb_net`: loaded; `usb_f_ncm`: absent.
- NCM MACs were the cold-boot regenerated values `02:00:00:00:00:01` and
  `02:00:00:00:00:02`.

## Recovery action

The helper was sent over the SSH chain and executed on T6A. Its first run
created the link but stopped at its string comparison: ConfigFS `readlink`
returned the relative display
`../../../../usb_gadget/g1/functions/ncm.gs8`, while the helper compared it to
the absolute target path. No UDC bind occurred in that first run.

The helper was minimally corrected to compare normalized targets using
`readlink -f`, matching the recorded successful absolute-target creation and
the actual ConfigFS representation. No recovery sequence was otherwise changed.

The corrected helper then performed:

1. preserve/create `f5 -> /config/usb_gadget/g1/functions/ncm.gs8`;
2. newline-terminated UDC unbind;
3. bind `11201000.usb`;
4. add `192.168.77.1/24` to `ncm0`;
5. set `ncm0` administratively UP.

## Post-recovery verification

- `f5` exists and displays as
  `../../../../usb_gadget/g1/functions/ncm.gs8`.
- `UDC=11201000.usb`; UDC state: `not attached`.
- `ncm0`: administratively UP, `NO-CARRIER`, MAC
  `02:00:00:00:00:01`.
- `ncm0`: `192.168.77.1/24`.
- carrier: `0`.
- `rx_errors=0`, `rx_dropped=0`, `tx_errors=0`, `tx_dropped=0`.
- Management `br-lan` remained UP at `T6A-MGMT-IP/24`.
- Ping to `192.168.77.2` sent 2 packets and received 0.

## Gate and conclusion

The T6A-side ConfigFS/NCM recovery is complete and matches the prior recorded
sequence. Windows enumeration, `UsbNcm Host Device`, Windows IP verification,
bidirectional ping, and iperf baseline cannot yet be measured because the USB
UDC remains `not attached` and `ncm0` has no carrier. No throughput claim is
made. The next action requires the intended Windows Pavilion USB host/VBUS
connection; then verify UDC `configured`, carrier, Windows `192.168.77.2/24`,
ping, and the established 1.34–1.37 / 1.01–1.02 Gbps baseline.

> Privacy note (2026-09-06): personal paths, management addresses and device MACs in this document are redacted or replaced with examples; they are not original measured identifiers.
