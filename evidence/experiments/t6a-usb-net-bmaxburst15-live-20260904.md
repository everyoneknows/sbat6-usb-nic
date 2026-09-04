# T6A usb_net bMaxBurst=15 temporary load — 2026-09-04

## FACT

- USB A-A cable was physically removed by 旦那さま before this operation.
- Before the change, T6A reported `MODE=3`, UDC `not attached`, xHCI absent,
  and `ncm0=down`. The vendor `/lib/modules/5.4.238/usb_net.ko` matched the
  known original SHA256 `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
- The candidate was copied to `/tmp` and matched SHA256
  `c70cffa54f6953ddaad5f1e57d130b50ee69eb7bdc2abc3415b2c9acd14808cf`.
- The NCM f5 link and unused ECM/RNDIS instances were released; module use
  count reached 0, and `rmmod usb_net` succeeded.
- The candidate loaded from `/tmp` with return code 0. No module ABI error,
  unknown-symbol error, oops, or call trace appeared.
- The known gadget configuration was restored: `f5 -> ncm.gs8`, `qmult=30`,
  UDC `11201000.usb` bound.
- After an 8-second stability observation: `MODE=3`, UDC state `not attached`,
  current speed `UNKNOWN`, `ncm0=down`, and candidate module use count `2`.
- The only matching recent warning was the pre-existing vendor `iwpriv`
  deprecation warning; no USB/NCM failure was observed.

## ACTIONS

- No permanent file was overwritten. `/lib/modules/5.4.238/usb_net.ko` stayed
  unchanged; the original was copied to
  `/tmp/butlerx-usb_net-bmaxburst15-before-20260904b/usb_net.original.ko`.
- T6A mode, GPIO, VBUS, flash, bootloader, and network/IP configuration were
  not changed.
- A zero-byte UDC write did not unbind and returned `No such device`; this was
  not treated as success. A subsequent newline-terminated unbind succeeded.

## VERDICT

`PASS — temporary candidate load and disconnected gadget restoration.`

Host-visible `bMaxBurst=15` and performance remain unverified until the cable
is connected and the host descriptor is captured.
