# T6A vendor USB role/VBUS investigation — 2026-09-03

## Scope and safety

Read-only investigation. No role, mode, VBUS, RT9467 register, GPIO,
register, DT, flash, reboot, or cable operation was performed. The existing
`f5 -> ncm.gs8` configuration was preserved.

## FACT — live T6A readback

- Linux `5.4.238`, vendor board `MediaTek evb6990_cpe_mt7990_emmc`.
- `/sys/class/udc/11201000.usb/state`: `not attached`.
- UDC function: `g1`; current speed `UNKNOWN`; maximum speed
  `super-speed-plus`.
- `/sys/devices/platform/11201000.usb/mode`: `2`.
- `/sys/devices/platform/11201000.usb/iddig_state`: `1`.
- `/sys/class/usb_role/11201000.usb-role-switch/role` does not exist; the
  role-switch directory and uevent do exist.
- `11200000.xhci0` and USB root hubs `usb1`/`usb2` exist.
- `/config/usb_gadget/g1/UDC`: `11201000.usb`.
- `/sys/firmware/devicetree/base/usb@11201000/dr_mode`: `otg`.
- The live DT contains `usb-role-switch`, `ql,gpio-names` of
  `usb_iddig usb_drvbus`, and `vusb33-supply`.
- The live DT contains RT9467 child regulator `usb-otg-vbus` at
  `i2c@11ed1000/rt9467@5b`; the MTU3 node's `mediatek,force-vbus` property
  exists.

## FACT — vendor userspace path

- `/etc/init.d/usb.init` unconditionally executes
  `echo 3 > /sys/devices/platform/11201000.usb/mode` in `start_service()`.
- `/etc/init.d/switch_otg_daemon` starts `/usr/bin/switch_otg_daemon` after a
  three-second delay; the daemon reads `iddig_state` and contains the literal
  commands `echo 1`, `echo 3`, and `echo 2` to the same `mode` node.
- The daemon's literals include `sync sw_otg to_host_mode` and
  `sync sw_otg to_deivce_mode` (vendor spelling preserved).
- `/etc/restart_usb.sh` only binds `g1` to `11201000.usb` and restarts
  `usb.init` if FunctionFS ADB is absent.
- `/usr/bin/mtk_usbnet_switch.sh ncm` changes the commented NCM link in
  `usb.init`, stops/restarts the whole gadget, and later brings the network
  interface up/bridges it. It is not a pure role switch path.

## FACT — vendor MTU3 source and built object

The source used for the retained vendor-compatible kernel build is
`work/build/linux-5.4.238-air6-upstream/drivers/usb/mtu3/mtu3_dr.c`; the
retained `mtu3_dr.o` contains the same symbols and disassembly.

- `ssusb_role_sw_set()` maps `USB_ROLE_HOST` to `to_host=true`, and calls
  `ssusb_mode_switch()` only when the requested role differs from
  `ssusb->is_host`.
- `ssusb_mode_switch(to_host=true)` does:
  `FORCE_HOST -> MTU3_VBUS_OFF -> MTU3_ID_GROUND`.
- `ssusb_mode_switch(to_host=false)` does:
  `FORCE_DEVICE -> MTU3_ID_FLOAT -> MTU3_VBUS_VALID`.
- `MTU3_VBUS_OFF` calls `mtu3_stop()`; `MTU3_VBUS_VALID` calls
  `mtu3_start()`.
- `MTU3_ID_FLOAT` sets `is_host=false`, calls `ssusb_set_vbus(..., 0)`, and
  switches the port to device. `ssusb_set_vbus(..., 0)` disables the optional
  MTU3 `vbus` regulator.
- `ssusb_set_vbus(..., 1)` enables that same optional regulator for host.

Therefore the normal HOST -> DEVICE ownership change is performed by the
MTU3 provider's `ssusb_role_sw_set()`/`ssusb_mode_switch()` path, not by
`extcon-usb-gpio` and not by a userspace RT9467 register write. Whether this
board's optional MTU3 `vbus` consumer resolves specifically to RT9467
`usb-otg-vbus` remains unproven; the live DT proves the regulator exists, but
not the resolved consumer link.

## FACT / INFERENCE — mode values and store path

The prior saved T6A reproduction captured the vendor mode handler's logs:

- starting `mode=2`, writing `1` logged `store mode 1 op_mode 2`, then
  `role_sw_set role 0`, xHCI deregistration, and device-port preparation;
- writing `3` from that state logged `store mode 3 op_mode 1`, then
  `role_sw_set role 2`, `mailbox VBUS_VALID`, PHY/device start and gadget
  pull-up.

Thus, for this vendor mode node:

- `MODE=1`: transition/neutral state; role `USB_ROLE_NONE` and xHCI stopped
  or deregistered.
- `MODE=2`: host operating state.
- `MODE=3`: device operating state.

The saved build's upstream MTU3 debugfs `mode` file is a different interface
and is absent from the live debugfs directory. The live platform `mode` file
is vendor-added/custom code: it is not `ssusb_mode_write()` from upstream
`mtu3_debugfs.c`. The exact vendor source file for that custom sysfs store
handler is not present in the retained source tree. Its implementation is
identified by its live log strings and behavior as the dispatcher that calls
the real role-switch callback.

The string `op_mode 2, skip set role` belongs to that vendor custom dispatcher:
the earlier direct role-switch helper reached the provider while its internal
mode was still `2`, and the dispatcher deliberately refused the transition.
The real provider callback is the built-in MTU3 `ssusb_role_sw_set()` above,
not the helper module.

## FACT / INFERENCE — VBUS and ordering

For the proven mode sequence, the safe first transition step is `MODE 2 -> 1`;
the second step is `MODE 1 -> 3`. The first step removes the host role and
stops/deregisters xHCI. The device step then invokes `USB_ROLE_DEVICE`, whose
provider order is `FORCE_DEVICE -> ID_FLOAT/VBUS-off -> VBUS_VALID/device
start`. The source-level role callback itself uses `ID_FLOAT` before
`VBUS_VALID`; the host-to-device VBUS-off is therefore owned by MTU3's
`ssusb_set_vbus(..., 0)` during the `ID_FLOAT` mailbox handling.

`usb.init`'s `mode=3` is a boot-time request, while `switch_otg_daemon` can
subsequently overwrite the mode according to IDDIG. The exact live daemon
branch mapping from `iddig_state=1` to its writes was not reconstructed from
source; boot-time final `MODE=2` is FACT, and the daemon-overwrite mechanism is
FACT, but the precise branch is UNKNOWN.

## FACT / INFERENCE — raspi4 enumeration failure

- The reported host log reached full-speed attach/descriptor read, then
  `error -32` and `error -71`, but no enumeration completed.
- At the same investigation point, T6A still had xHCI present, `mode=2`, UDC
  `not attached`, and `current_speed=UNKNOWN`.

This is most consistent with HOST-HOST use of an A-A cable: both sides can
present host-side behavior while no device-side pull-up/descriptor responder
exists. It is also consistent with a cable/power topology problem. It is not
evidence of a functioning T6A gadget. A pure gadget-response failure cannot be
excluded from the old host log alone, but is secondary because the T6A live
state proves it was not yet in the device operating state.

## Next safest one operation — STOP

After a separately approved physical safety gate (no A-A cable connected,
VBUS measurement plan, and host-side capture ready), the next single T6A
operation is only:

`printf 1 > /sys/devices/platform/11201000.usb/mode`

Then stop and re-snapshot. Do not issue the `3` step in this task. This report
does not execute that operation.
