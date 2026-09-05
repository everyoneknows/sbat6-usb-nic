# T6A MTK ABI compatibility candidate functional test — stopped on Oops — 2026-09-05

## Scope and management

The authorized path was `agent-101-vm -> raspi2 -> LAN/SSH -> root@T6A-MGMT-IP`.
ADB, `sbat6_usb_role_runtime2.ko`, RPS/IRQ affinity/backlog/queue/NTB/qdisc/
descriptor/streams/performance-source changes were not used. Windows was not
connected.

Precheck reached T6A over SSH. The target initially had vendor `usb_net`
refcount 6, UDC `11201000.usb`, state `not attached`, `mode=2`, GPIO322=1,
and xHCI present. Ping from raspi2 to `T6A-MGMT-IP` failed, but the authorized
SSH path was available; SSH was used as the management continuity test.

## Artifact verification

- candidate `usb_f_ncm-extended.ko`: SHA256
  `1fb49fd6cf347e2676327d92a22808ee0d767792dcbc52261d2d41b81b0afc06`
- telemetry `sbat6_ncm_telemetry.ko`: SHA256
  `94b157ad17cbe678f2484d058b2e5f8231e5ed6de6fe33f8349ee1588ca6ebf5`
- both hashes matched after transfer to T6A `/tmp`.

## Candidate setup

Vendor release was completed using the known safe instance-owner procedure:

```text
ncm.gs8   rmdir RC=0, usb_net 6 -> 4
ecm.gs8   rmdir RC=0, usb_net 4 -> 2
rndis.gs4 rmdir RC=0, usb_net 2 -> 0
rmmod usb_net RC=0
```

Telemetry loaded with RC=0. Candidate loaded with RC=0 and was `[permanent]`.
The candidate ConfigFS instance was created with all four attributes present:

```text
dev_addr=06:a2:ed:c1:80:59
host_addr=fa:28:57:07:6b:6c
qmult=30
ifname=(unnamed net_device)
```

The authorized device-mode preparation succeeded:

```text
mode 2 -> 3
GPIO322 1 -> 0
xHCI present -> absent
```

## Failure and stop

The absolute f5 link to the candidate function succeeded. During the required
UDC unbind/rebind, the T6A management SSH session stopped responding. Repeated
SSH attempts timed out for about one minute. No further candidate operation,
Windows connection, IP setup, ping, or iperf was attempted.

The resulting pstore record shows:

```text
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000000
Internal error: Oops: 96000046 [#1] SMP
pc : gether_register_netdev+0x2c/0x8c [usb_f_ncm]
lr : ncm_bind+0x8c/0x2d4 [usb_f_ncm]
Call path: gether_register_netdev -> ncm_bind -> usb_add_function
             -> configfs_composite_bind -> udc_bind_to_driver
```

This is classified as a kernel anomaly in the candidate bind path. Repeating
the same condition is prohibited.

## Recovery verification

T6A rebooted automatically and SSH recovered. Post-reboot state:

```text
usb_net 77824 6
usb_f_ncm absent
sbat6_ncm_telemetry absent
f1..f4 present and unchanged
f5 absent
UDC=11201000.usb
UDC state=not attached
current_speed=super-speed
mode=2
GPIO322=1
ncm0 absent
```

No vendor function instance was left removed. The post-reboot pstore record was
copied to `evidence/pstore/20260905/functional-oops-20260905/console-ramoops-0`.

## Classification

```text
CANDIDATE_INSMOD=PASS
CONFIGFS_INSTANCE=PASS
F5_LINK=PASS
UDC_CONFIGURED=NOT_REACHED
USB_NCM_ENUMERATION=NOT_RUN
NCM0_LINK=NOT_REACHED
BIDIRECTIONAL_PING=NOT_RUN
IPERF_BASELINE=NOT_RUN
KERNEL_ANOMALY=FAIL
USB_NCM_FUNCTIONAL=FAIL
IPERF_BASELINE=NOT_RUN
VENDOR_RESTORE=PASS
```

No throughput comparison is claimed.
