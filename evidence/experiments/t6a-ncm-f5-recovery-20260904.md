# T6A CDC-NCM f5 recovery — 2026-09-04

## Scope and safety

The target was accessed only through `agent-101-vm -> raspi2 -> SSH root@T6A-MGMT-IP`
using the configured SSH identity. ADB, USB role changes, physical power
cycling, reboot, flash, eFuse, and persistent configuration changes were not used.

## Evidence before recovery

- LAN/SSH was available and `br-lan` retained `T6A-MGMT-IP/24`.
- `/config` was the ConfigFS mountpoint.
- `g1/functions/ncm.gs8` existed, while `configs/b.1/f5` was absent.
- Existing `f1..f4` were ACM/FFS links.
- `UDC` contained `11201000.usb`, but UDC state was `not attached`; current speed
  was `super-speed`.
- Vendor `usb_net` was loaded; `usb_f_ncm` was absent.
- `ncm.gs8` retained `qmult=30`, device and host MAC attributes, and an unnamed
  netdev. Gadget identity was VID `0x2c7c`, PID `0x7006`, bcdUSB `0x0320`,
  bcdDevice `0x0223`.
- The live pre-recovery snapshot was saved on T6A as
  `/tmp/butlerx-t6a-recovery-before-20260904-191150/`.
- Earlier vendor recovery evidence explicitly records `f5 -> ncm.gs8` and that
  the absolute link creation succeeded after the relative attempt failed.

## Recovery

The missing link was restored as:

`/config/usb_gadget/g1/configs/b.1/f5 -> /config/usb_gadget/g1/functions/ncm.gs8`

The existing UDC was then unbound with a newline-terminated empty ConfigFS write
and rebound to `11201000.usb`. No other function link was changed.

## Verification

- `f1..f5` were present; `f5` pointed to `../../../../usb_gadget/g1/functions/ncm.gs8`
  in `ls -l` output.
- dmesg recorded `ncm_bind`, `gether_register_netdev`, and NCM endpoint creation.
- `ncm0` appeared with MAC `02:00:00:00:00:06`.
- `192.168.77.1/24` was restored after netdev creation and `ncm0` was set UP.
- Management LAN remained `br-lan UP T6A-MGMT-IP/24`.
- T6A-side counters remained zero and showed no NCM errors.
- At the end, `ncm0` was `UP` administratively but `NO-CARRIER`, carrier `0`,
  and UDC state remained `not attached`. Thus USB host enumeration, Windows
  `UsbNcm.sys`, ping, and iperf are not yet verifiable without host/VBUS attach.

## Known non-working / negative knowledge

- The candidate `usb_f_ncm` integration was incompatible with this vendor
  ConfigFS state: rollback left the vendor `ncm.gs8` directory but removed the
  `b.1/f5` link. The prior rollback stopped before restoring the link.
- A relative-link spelling copied from the displayed `f1..f4` targets failed with
  `No such file or directory`; the vendor-compatible absolute target succeeded.
- `echo -n > UDC` did not clear the ConfigFS UDC field on this BusyBox build;
  newline-terminated `echo > UDC` is required. An attempted bind while the field
  remained populated returned `Resource busy` and caused no damage.
- `usb_f_ncm` must not be loaded alongside the vendor provider in future tests
  until provider ownership and a tested recovery path are established.

## Next gate

Do not repeat candidate replacement. First attach the intended USB host and
verify UDC configured, carrier, Windows `UsbNcm Host Device`, `192.168.77.2`,
bidirectional ping, and the established iperf baseline (about 1.34–1.37 Gbps
T6A→Windows and 1.01–1.02 Gbps Windows→T6A).
