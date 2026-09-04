# T6A CDC-NCM A班 observation-only candidate — blocked after guarded rollback — 2026-09-04

## Baseline gate (before candidate)

The authorized path was `agent-101-vm -> raspi2 -> LAN/SSH -> root@192.168.3.2`.
ADB, runtime2, USB role/mode changes, flash, reboot, and GPIO writes were not
used. Before the candidate operation, the live gate was:

- mode `3`; GPIO322 `0` (LOW); xHCI absent
- UDC `11201000.usb`, state `configured`, current speed `super-speed`
- `f5 -> /config/usb_gadget/g1/functions/ncm.gs8`
- `ncm0 LOWER_UP`, carrier `1`, `192.168.77.1/24`
- T6A -> Windows ping: 3/3, 0% loss
- forward iperf3: `1.392`, `1.375`, `1.378 Gbit/s`, Retr `0`
- reverse iperf3: `1.01`, `1.01`, `1.01 Gbit/s`

The pre-candidate snapshot was created on T6A at:
`/tmp/butlerx-t6a-observation-before-20260904-215332`.
The ConfigFS tar emitted a BusyBox `tar: short read` for pseudo-files, so the
individual ConfigFS attributes, links, UDC, NCM, and module-parameter files
were also saved separately in that snapshot.

## Candidate ABI

- `sbat6_ncm_telemetry.ko` SHA256:
  `94b157ad17cbe678f2484d058b2e5f8231e5ed6de6fe33f8349ee1588ca6ebf5`
- `usb_f_ncm.ko` SHA256:
  `d2257ff360fa82c6f2ea639a9856ebd5db7e018b1e71c1113eb74e48ffe7e783`
- both: `5.4.238 SMP mod_unload modversions aarch64`
- sink dependency: empty
- candidate dependency: `sbat6_ncm_telemetry`
- all imported telemetry CRCs matched the rebuilt sink map

## Replacement result

The guarded replacement created a snapshot at
`/tmp/butlerx-t6a-candidate-20260904-215606`, unbound the UDC, and unloaded
the vendor provider. Candidate installation stopped while restoring the
vendor function attribute `ifname`: the candidate ConfigFS instance exposes
that attribute read-only. No candidate performance or telemetry run was made.

The script entered rollback. Vendor `usb_net` was restored and `f5` was
restored to `ncm.gs8`. The follow-up recovery re-bound the UDC without
changing mode, GPIO, role, or persistent settings.

## Current state after rollback

- management LAN: alive, `br-lan 192.168.3.2/24`
- vendor `usb_net`: loaded
- `f5 -> ncm.gs8`: restored
- UDC: bound, currently `not attached`
- `ncm0`: present with `192.168.77.1/24`, but `NO-CARRIER`
- candidate and telemetry sink: not loaded

The USB host must be physically re-enumerated before the next gate check.
The replacement helper was corrected to skip writes to read-only `ifname`
during candidate setup and rollback; shell syntax validation passed. A second
attempt confirmed the earlier failure point: `rmmod usb_net` is refused while
the vendor aggregate has refcount `6`, because the existing unlinked
`ecm.gs8`, `rndis.gs4`, and other function instances still hold references.
Removing those instances to force the unload would violate the requirement not
to destroy the existing ConfigFS, so it was not attempted.

The final recovery restored `UDC=configured`, `current_speed=super-speed`,
`ncm0 LOWER_UP`, carrier `1`, mode `3`, GPIO322 `0`, and the vendor
`usb_net` only. No candidate module is loaded.

Decision: `BLOCKED`; rollback completed, no candidate result claimed.
