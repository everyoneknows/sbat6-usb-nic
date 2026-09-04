# T6A CDC-NCM current baseline repeat — 2026-09-04 13:23 JST

## Purpose

The requested read-only difference check between the known 1.33 Gbit/s state
and the 473 Mbit/s state was followed by three unchanged P1 repetitions.
No module, ConfigFS, USB, IP, MTU, qdisc, offload, or trace configuration was
changed during this check.

## Current state snapshot

- T6A `ncm0`: `UP/LOWER_UP`, `192.168.250.1/30`, MTU 1500, qdisc `fq_codel`
- raspi4 `usb0`: `UP/LOWER_UP`, `192.168.250.2/30`, MTU 1500, qdisc `fq_codel`
- raspi4 `cdc_ncm`: `tx_timer_usecs=400`, `tx_max=16384`, `rx_max=16384`,
  `min_tx_pkt=13312`
- USB state: SuperSpeed; prior and current wrapper/descriptor checks report
  CDC-NCM bulk endpoint `bMaxBurst=15`
- T6A tracefs: `/sys/kernel/debug/tracing/tracing_on=1`,
  `/sys/kernel/debug/tracing/events/enable=0`; no enabled event was found
- T6A `usb_net.ko`: SHA256
  `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`
- T6A CPU readback: 1.61 GHz on all four CPUs, governor `schedutil`; load
  average about `9.69 9.77 9.83`
- raspi4 CPU readback: 1.50 GHz on all four CPUs, governor `ondemand`; load
  average `0.01 0.13 0.10`
- Offloads match the previously recorded NCM setup: T6A checksum off,
  GSO/GRO on; raspi4 offload readback was unavailable because `ethtool` is
  not installed for `kuroko-lab`
- No iperf3 process remained after each one-off server measurement

## P1 repetitions

Command on T6A for every run: `iperf3 -c 192.168.250.2 -t 10`.

| run | throughput | Retr | result |
|---|---:|---:|---|
| 1 | 1.34 Gbit/s | 0 | success |
| 2 | 1.30 Gbit/s | 0 | success |
| 3 | 1.31 Gbit/s | 0 | success |

The 473 Mbit/s state was not reproduced. The current state is therefore a
stable high-rate baseline over three repetitions, within the known
1.30–1.35 Gbit/s range.

## Difference judgment

The only controlled state change immediately preceding recovery was the
reversible T6A trace event master switch: `events/enable 1 -> 0`, while
`tracing_on` remained `1`. This reproduces the earlier A/B result of
approximately 482 Mbit/s -> 1.33 Gbit/s. CPU frequency/governor, qdisc,
NCM values, MTU, IP/carrier, endpoint burst, and module identity show no
positive evidence of being the recovery trigger.

T6A and raspi4 counters remained error-free for the new traffic interval
(the raspi4 cumulative `usb0` counters remain RX/TX errors `1/1`, drops `187/7`,
unchanged from the prior snapshot). T6A kernel-log tail contained unrelated
Wi-Fi/GPS warnings and no USB/NCM reset, timeout, or stall.

## Remaining limitation

The dedicated raspi4 wrapper exposes NCM state and IRQ/log observation but not
all raw host sysfs/module/offload files; `ethtool` and `modinfo` are absent for
the observation account. ConfigFS `qmult` was not exposed by the current T6A
read-only path, so the previously established `qmult=30` remains the retained
FACT, not a newly read raw value in this snapshot.
