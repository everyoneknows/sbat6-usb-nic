# T6A CDC-NCM trace overhead A/B and baseline usbmon — 2026-09-04

## Cause isolation

The previously reproduced low-rate state was measured without usbmon capture:
T6A -> raspi4 P1 was 482 Mbit/s, Retr 0.  Read-only checks showed the same
SuperSpeed/CDC-NCM condition as the high-rate record: negotiated USB speed
5Gbps, CDC-NCM bulk IN/OUT `wMaxPacketSize=1024`, `bMaxBurst=15`,
`tx_max=rx_max=16384`, `min_tx_pkt=13312`, MTU 1500, qmult 30, and configured
UDC.

The T6A tracefs master event switch was then changed only for one reversible
A/B test:

- before: `events/enable=1`, `tracing_on=1`
- test: `events/enable=0`, `tracing_on=1`
- result: **1.33 Gbit/s**, Retr 0, 10.00 s
- after test: trace event state was restored for the capture, then left at
  `events/enable=0`, `tracing_on=1` to retain the recovered high-rate baseline

The direct A/B result identifies the enabled trace event set as the cause of
the 482 Mbit/s state. This is a reversible diagnostic configuration issue, not
evidence of a bMaxBurst, NCM-size, USB-speed, or host-URB shortage.

## Baseline capture

With trace events disabled and all network/USB parameters unchanged:

- T6A -> raspi4 P1: 1.30 Gbit/s overall, Retr 187; steady intervals were
  1.33–1.35 Gbit/s after startup
- capture: `/srv/t6a-lab/ncm-p1-baseline-traceoff.pcap`, 441 MiB
- capture duration: permitted 20 seconds, `usbmon2`
- T6A: UDC `configured`, `current_speed=super-speed`, `ncm0` MTU 1500,
  carrier 1, qmult 30
- raspi4: `usb0` UP, `192.168.250.2/30`, carrier 1; NCM timer 400 us,
  tx/rx max 16384, min_tx_pkt 13312
- relevant bulk descriptors remained `bMaxBurst=15`; negotiated speed 5Gbps

The capture parser found 92,838 records and 69,616 bulk IN records:

- 40,071 IN submits, all requested length 16,384 bytes
- 29,545 data completions
- completion lengths: 15,224 bytes (28,934), 13,832 (456), 14,528 (122),
  with only small edge counts elsewhere
- completion interval median 38.86 us, p95 424.86 us
- no ZLP was promoted from this pcap; usbmon completion framing does not
  distinguish protocol short packets by itself

The parser's raw outstanding counter is boundary-affected and must not be
treated as a steady-state in-flight count. Together with the earlier capture,
the safe conclusion remains host IN requests at 16 KiB and at least 64-request
scale in flight; this does not support host request starvation.

The vendor NCMH layout prevents this parser from safely extracting a new exact
NDP/datagram count. The independently established FACT remains approximately
10 datagrams per NTB with NDP aggregation active. The repeated 15,224-byte
completion cluster again shows that the 16 KiB request/NTB ceiling is not
normally filled to exactly 16,384 bytes.

## Updated priority

1. trace/debug event overhead (confirmed cause of the observed 474–482 Mbit/s
   state; event recording is now disabled)
2. gadget/NCM flush and block packing below the 16 KiB ceiling
3. data-path serialization (single queue/lock) and copy/DMA cost
4. MTU3 QMU/GPD batching or starvation (64-entry ring exists, but no evidence
   of ring starvation under high load)
5. host URB/request supply (downgraded: 16 KiB requests and >=64 scale seen)
6. bMaxBurst=15 / USB link speed (confirmed correct in the recovered run)

The trace-event switch is a reversible runtime setting. No module, role, UDC,
ConfigFS, IP, MTU, or physical connection change was made in the final state.
