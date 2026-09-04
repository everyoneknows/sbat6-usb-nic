# T6A USB CDC-NCM host interface confirmation — 2026-09-04

## Scope and stop condition

This record preserves the state at the requested stop point. The experiment
must stop once the raspi4 host exposes the CDC-NCM interface. No IP address,
route, DHCP, bridge, NAT, or packet-communication setup is to be performed
in this step.

## Proven state immediately before host confirmation

These values were already recorded during the preceding controlled transition:

- T6A `GPIO322=LOW`.
- T6A USB-A `VBUS=0 V`, measured physically by 旦那さま before cable attach.
- T6A vendor USB `MODE=3` (device operating state).
- T6A xHCI: `ABSENT`.
- T6A UDC: `g1` bound, state `not attached`.
- T6A `ncm0`: present and `DOWN`.

The preceding evidence is in `t6a-usb-20260903-reclassification.md` and
`t6a-ncm-enable-20260903.md`.

## Host-side result

- Source: 旦那さま's Discord report received on 2026-09-04.
- Reported result: `CDC-NCM host interface usb0 confirmed` on raspi4.
- Interpretation: the requested host-side interface appearance condition is
  confirmed by the operator's observation.
- Raw raspi4 `dmesg` output was not transferred into this repository in this
  step; this record therefore preserves the report and does not claim a raw
  log capture.

## Actions and non-actions

- Saved this evidence record and the corresponding current-state record.
- Did not connect or disconnect hardware from this environment.
- Did not change T6A mode, GPIO, VBUS, UDC, ConfigFS, USB functions, IP
  addresses, routes, bridges, or firewall settings.
- Did not request or perform further host traffic tests.

## Verdict

`PASS — requested CDC-NCM host interface appearance condition reached.`

`STOP — IP configuration and all subsequent networking tests deferred.`

## Remaining unknowns

- Actual IP-layer communication was not tested.
- NCM packet transfer was not tested.
- The complete raw raspi4 kernel log is not retained here.
