# T6A CDC-NCM usbmon P1 high-rate capture — 2026-09-04 13:04 JST

## Conditions and execution

- T6A `ncm0`: `UP/LOWER_UP`, `192.168.250.1/30`, carrier `1`
- raspi4 `usb0`: `UP`, `192.168.250.2/30`, carrier `1`
- SuperSpeed 5,000M
- USB device `2c7c:7006`: bus 2, device 9; capture interface `usbmon2`
- CDC-NCM bulk IN EP8 and OUT EP5: `wMaxPacketSize=1024`, `bMaxBurst=15`
- No module, role, USB binding, IP, MTU, or descriptor changes
- raspi4 temporary `iperf3 -s -1` and permitted 20-second capture were used
- T6A command: `iperf3 -c 192.168.250.2 -t 10`

## P1 result

- Transfer: 565 MiB
- Duration: 10.02 s
- Throughput: 473 Mbit/s
- Retr: 0
- Exit status: 0
- Capture: `/srv/t6a-lab/ncm-p1-highrate.pcap`, 465 MiB

## usbmon measurements

The pcap contained 87,360 records. For bus 2/device 9 bulk IN EP8:

- 34,027 submit records; every submit request length was 16,384 bytes
- 31,333 completion records with data
- Completion lengths: 15,224 bytes (27,936), 14,528 (3,354), 13,832 (19); the remaining 24 were setup/edge-sized completions
- Completion interval median: about 150 microseconds
- Completion interval p95: about 645 microseconds
- Submit/complete boundary difference was 2,694 records; this is a capture-window accounting difference, not a steady-state in-flight count

NCM payload completions were present in all 31,333 data completions. The exact NDP/datagram count was not promoted from this run because the capture uses a vendor NCMH layout whose block-length field is not the standard offset; the earlier capture independently established 28,715/28,715 NCM completions and predominantly 10-datagram NTBs. This run therefore confirms the same transfer envelope and NCM payload activity, but does not claim a new NDP count.

No ZLP or short-packet distinction is claimed from the pcap alone. The non-16,384 completion lengths are short-ending completion lengths; usbmon does not by itself distinguish USB protocol short packet from capture framing.

## Post-check

- raspi4 `usb0` carrier remained `1`
- `192.168.250.2/30` remained present
- raspi4 `usb0` RX/TX error counters remained `1/1`
- Relevant CDC-NCM bulk endpoints remained `bMaxBurst=15`
- Temporary iperf server exited after the one-off measurement

## Judgment and next priority

The host is supplying 16 KiB IN requests at high load, and the observed completion cadence is approximately the prior run's cadence. The 16 KiB request ceiling is not being reached by most completed transfers (15,224/14,528-byte clusters). Host request starvation is therefore downgraded. Gadget flush/aggregation policy, NCM block packing, and data-path serialization/copy-DMA remain higher-priority hypotheses; MTU3 ring starvation is not supported by this capture alone.
