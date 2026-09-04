# T6A usb_net bMaxBurst=15 attached verification — 2026-09-04

## FACT

- After 旦那さま reconnected the USB A-A cable, T6A was read through the
  authorized `agent-101-vm -> raspi2 -> 192.168.3.2` path.
- At 2026-09-04 10:19:49 JST, UDC `11201000.usb` reported `configured` and
  `current_speed=super-speed`.
- T6A remained in vendor USB `mode=3`; GPIO322 remained `0`.
- Gadget `g1` remained bound to `11201000.usb` and its NCM function reported
  `ifname=ncm030`, `qmult=30`.
- The temporary candidate remained loaded (`usb_net`, use count 2).
- `ncm0` existed but was `DOWN`, with RX/TX counters at zero. No IP, DHCP,
  route, bridge, or traffic test was performed.
- The original module remained unchanged: `/lib/modules/5.4.238/usb_net.ko`
  SHA256 `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
  The temporary candidate SHA256 was
  `c70cffa54f6953ddaad5f1e57d130b50ee69eb7bdc2abc3415b2c9acd14808cf`.

## VERDICT

`PASS — USB gadget enumerated at SuperSpeed with the temporary candidate.`

Host-side descriptor capture and IP-layer communication remain unverified.

## 2026-09-04 11:29–11:32 JST follow-up

The cable was present (`iddig_state=1`) and T6A remained in vendor `mode=3`.
The first read showed the existing gadget configuration with `f5 -> ncm.gs8`
and the temporary `usb_net` module in use, but `/config/usb_gadget/g1/UDC`
was empty. No module, mode, GPIO, or persistent configuration was changed.

The existing UDC was rebound with the reversible write:

    printf %s 11201000.usb > /config/usb_gadget/g1/UDC

After 3 seconds T6A reported:

- UDC: `configured`
- speed: `super-speed`
- NCM function: `ncm030`, `qmult=30`
- candidate module use count: 2
- no new USB/NCM oops, reset, stall, timeout, or call trace in the observed log

For the planned traffic check, the temporary address `192.168.250.1/30` was
added to `ncm0` and the interface was brought up. The peer did not respond:

- peer ARP: `192.168.250.2 FAILED`
- ping: 0/3 replies
- `iperf3 -c 192.168.250.2 -R -t 10`: failed with `Host is unreachable`

The temporary address was removed and `ncm0` was returned to `DOWN`. The UDC
remains bound and `configured / super-speed`; the candidate remains loaded.

## Result

`PARTIAL PASS — T6A re-enumerated at SuperSpeed after UDC rebind; host-side
NCM endpoint and throughput verification are blocked by the absent/unconfigured
raspi4 peer.`

No throughput number or `bMaxBurst` value is claimed from this attempt.
