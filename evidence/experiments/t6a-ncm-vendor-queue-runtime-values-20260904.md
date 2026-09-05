# T6A vendor NCM queue sizing runtime values — 2026-09-04

## Scope

Read-only inspection through `agent-101-vm -> raspi2 -> root@T6A-MGMT-IP`.
No ConfigFS, module parameter, trace event, endpoint, module, or firmware
state was changed.

## Live state

T6A kernel is `5.4.238`; `usb_net` is loaded at `.text` base
`0xffffffc0097cc000`. The current function is `ncm.gs8`, `ifname=ncm0`, and
ConfigFS reports `qmult=30`.

The module's existing read-only parameter files report:

```text
tx_buff_num=0
uether_usb_request_qlen=80
uether_tx_max_aggr_num=10
u_ether_tx_req_threshold=1
qmult=30
```

The existing gadget and MTU3 tracepoints are present but all relevant
allocation/queue/completion events are disabled. No trace configuration was
changed. No existing vendor counter exposes the request-list lengths.

## Field mapping

The `.rela__param` entries map:

```text
rodata+0x5d4  tx_buff_num                  -> .bss+0x24
rodata+0x63d  uether_usb_request_qlen      -> .data+0x58
```

In `gether_connect` (`.text+0x3394`):

```text
w26 = load(.data+0x58)                   # uether_usb_request_qlen
dev[454] = byte at link private object + 454
w27 = w26 / dev[454]
if (.bss+0x24 != 0)
        w27 = min(tx_buff_num, w26)
```

This is the literal AArch64 behavior: `udiv` computes the quotient, then
`cmp w26,w0` followed by `csel w27,w0,w26,cs` caps against `w26`, not against
the quotient. Thus the requested expression
`min(.bss+0x24, w26 / dev[454])` is **not** the expression implemented by this
object. For the current `tx_buff_num=0`, the cap branch is inactive and both
descriptions reduce to the quotient.

The saved object initializes `.data+0x58` to 80. The live parameter file
confirms that value, so **FACT: `w26=80` for the current loaded module**.
The live parameter file confirms **FACT: `.bss+0x24` / `tx_buff_num=0`**.

The store to `dev+456` is `w27`; the following store to `dev+460` is
`(w27 << 1) / 3`. The allocator calls pass `w26` to the OUT/RX endpoint
(`dev+232`) and `w27` to the IN/TX endpoint (`dev+224`). The anonymous helper
at `.text.unlikely+0x25c` calls `usb_ep_alloc_request()` once per iteration.

## Meaning of `dev[454]`

The previous description of this byte as speed-related is corrected. The only
write recovered in the vendor object is in the retained
`gether_usb_bus_suspend` path (`.text.unlikely+0x84`): it calls the imported
`ppe_usb_tx_link_num_hook`, adds one to its return value, clamps the result to
the range 1..9, and stores it at `dev+454`. The field is then used as a loop
bound/divisor in disconnect and request bookkeeping paths.

Therefore:

* **FACT:** `dev[454]` is the vendor TX-link-count/bookkeeping byte, constrained
  to 1..9 when that PPE hook path updates it; it is not the USB negotiated
  speed and not the MTU3 GPD count.
* **UNKNOWN:** the current byte value in the live `ncm0` private object. No
  existing sysfs, debugfs, trace, log, or `/proc/kallsyms` interface exposes
  this private object field. `ncm0` having one Linux TX queue and MTU3 having
  64 GPD entries does not prove this byte's value.

## Current numerical conclusion

With the live values that are directly observable:

```text
w26 = 80
.bss+0x24 = tx_buff_num = 0
w27 = 80 / dev[454]
TX request objects allocated at connect = w27 iterations,
subject to allocation failure
```

Because `tx_buff_num` is zero, the cap branch is inactive. If and only if the
live PPE TX-link byte is 1, the result is `w27=80`; values 2..9 would produce
`40, 26, 20, 16, 13, 11, 10` respectively (integer division). The exact
vendor TX request count is therefore **not yet proven numerically**.

The existing `usb_ep_queue` path queues RX requests one at a time through
`rx_fill`; `gether_connect` has no direct TX bulk-prequeue loop. TX requests
are allocated into the vendor list and are submitted later by the TX path.
The 64-entry MTU3 GPD ring remains a controller descriptor capacity, not a
gadget `usb_request` count.

## Read-only observation decision

The available gadget/MTU3 trace formats could identify request pointers and
endpoint names if enabled, but enabling them would change runtime trace state
and previously caused a large throughput perturbation. They remain disabled.
The remaining proof requires either an already exposed vendor field/counter or
a separately authorized minimal observation mechanism; no such mechanism was
used here.
