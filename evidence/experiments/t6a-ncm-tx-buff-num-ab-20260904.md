# T6A vendor NCM `tx_buff_num` A/B experiment — 2026-09-04

## Scope and safety

T6A `usb_net` module parameter `tx_buff_num` was changed through its existing
runtime parameter file.  After every value change, the value was read back and
the existing gadget UDC was reconstructed with the known reversible procedure:

```text
/config/usb_gadget/g1/UDC <- newline       # unbind
/config/usb_gadget/g1/UDC <- 11201000.usb  # bind
```

No physical cable operation, module reload, trace-event enablement, firmware,
mode, role, IP, MTU, or persistent configuration change was performed.

The first attempted `/sys/kernel/config/...` path did not exist and was not
treated as a successful reconnect.  The actual T6A ConfigFS mount is
`/config`, and the subsequent unbind/rebind succeeded.

## Conditions and results

All successful conditions had T6A UDC `configured`, `ncm0` carrier `1`,
`192.168.250.1/30`, and raspi4 `usb0` carrier `1`,
`192.168.250.2/30` after the temporary address was restored by the permitted
raspi4 lab wrapper.  The host observed SuperSpeed 5 Gbps and the CDC-NCM data
endpoints reported `bMaxBurst=15` at the final check.

| condition | read-back | intended `w27` / allocation request | P1 T6A → raspi4 | Retr | result |
|---|---:|---:|---:|---:|---|
| baseline | 0 | legacy `80/dev[454]` (candidate 16) | 1.33 Gbit/s | 0 | successful |
| A | 32 | 32 | 1.31 Gbit/s | 72 | successful, no improvement |
| B | 64 | 64 | 1.31 Gbit/s | 168 | successful, no improvement |
| C | 80 | 80 | 1.30 Gbit/s | 58 | successful, no improvement |
| rollback | 0 | legacy `80/dev[454]` (candidate 16) | 1.28 Gbit/s | 117 | restored |

Each P1 used `iperf3 -c 192.168.250.2 -t 10`.  The retransmission and
throughput variation is not consistent with a monotonic benefit from the
override.  No condition produced a reproducible improvement, so the requested
repeatability gate and P4 were not entered.

## Allocation evidence and limitations

The parameter read-back proves the requested input value, and the static
vendor analysis proves the non-zero calculation is `min(tx_buff_num, 80)`.
The existing read-only interfaces do not expose the vendor TX request-list
length or successful allocation count, so the table does **not** claim that
32/64/80 requests were all successfully allocated.  No partial-allocation
counter was available through the retained debugfs/proc/sysfs paths.

The permitted raspi4 usbmon wrapper was attempted for baseline but tcpdump
returned rc=1; no pcap or completion interval statistics were promoted.  The
failure is recorded as missing data, not as a zero interval.  No trace event
was enabled.

## Health and final state

After every reconnect, UDC and carrier returned successfully.  Final
read-back:

```text
tx_buff_num=0
uether_usb_request_qlen=80
qmult=30
UDC=configured
ncm0=UP/LOWER_UP 192.168.250.1/30
raspi4 usb0=UP/LOWER_UP 192.168.250.2/30 carrier=1
```

No endpoint disable, USB stall, oops, kernel call trace, carrier recovery
failure, or rollback failure was observed.  raspi4 had no residual iperf3
process.  Its final descriptor check showed SuperSpeed and `bMaxBurst=15` for
the NCM data endpoints.  The device-number changes in raspi4 dmesg correspond
to the intentional UDC reconnects.

## Judgment

The experiment does not support the hypothesis that increasing the vendor TX
request allocation from the current candidate 16 to 32, 64, or 80 improves
T6A → raspi4 throughput.  Because actual vendor allocation counts and
completion intervals were not observable, it does not distinguish allocation
failure/partial success from a genuinely ineffective larger pool.  The T6A is
left at the known baseline setting `tx_buff_num=0`.
