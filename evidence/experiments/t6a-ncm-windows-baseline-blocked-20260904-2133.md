# T6A CDC-NCM Windows baseline recheck — blocked by USB high-speed — 2026-09-04

管理経路は `agent-101-vm -> raspi2 -> LAN/SSH -> root@192.168.3.2` のみ。
ADB、runtime2、USB role操作、candidate差替えは使用していない。

## Current T6A state

- UDC: `configured`
- `current_speed`: `high-speed` (要求された `super-speed` ではない)
- ConfigFS: `f5 -> /config/usb_gadget/g1/functions/ncm.gs8`
- gadget VID/PID: `0x2c7c:0x7006`
- `ncm0`: `UP`, `LOWER_UP`, carrier `1`
- T6A address: `192.168.77.1/24`
- NCM MACs: device `02:00:00:00:00:01`, host `02:00:00:00:00:02`
- qmult: `30`
- post-test errors/drops: RX errors/dropped `0/0`, TX errors/dropped `0/0`
- peer `192.168.77.2` is `REACHABLE`

The pre-candidate snapshot was saved on T6A as:
`/tmp/butlerx-t6a-recovery-before-20260904-213043`.

## Connectivity

T6A -> Windows ping: 3/3 replies, 0% loss, 2.669–3.468 ms RTT.
The reverse iperf3 direction below also verified data transfer from the Windows
iperf3 server to T6A. A Windows-originated ICMP ping was not directly issued
because no Windows shell/control channel is available through the authorized
management path.

## iperf3 baseline recheck

Windows was used as the iperf3 server at `192.168.77.2:5201`. Each direction
was run three times for 10 seconds, with 3 seconds between runs. No busy-server
failure occurred.

| Direction | Run 1 | Run 2 | Run 3 | Expected baseline |
|---|---:|---:|---:|---:|
| T6A -> Windows | 350 Mbit/s | 350 Mbit/s | 350 Mbit/s | 1.34–1.37 Gbit/s |
| Windows -> T6A (`iperf3 -R`) | 333 Mbit/s | 333 Mbit/s | 333 Mbit/s | 1.01–1.02 Gbit/s |

All forward runs reported Retr `0`.

## Decision

Baseline did **not** return. The observed throughput is consistent with the
simultaneously observed USB `high-speed` negotiation, not the expected
SuperSpeed path.

The successful primary-sequence procedure was **not** appended as a success,
and the A班 observation-only telemetry candidate was **not** installed or
loaded. The next action requires resolving why the Pavilion link negotiated
high-speed (physical port/cable/host path or re-enumeration), then repeating
the same read-only preflight and three-run baseline.
