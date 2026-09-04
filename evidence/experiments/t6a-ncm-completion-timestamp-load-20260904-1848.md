# T6A NCM completion timestamp implementation and load attempt — 2026-09-04

## Implementation

The vendor `u_ether.c` now uses a 64-slot fixed hash table keyed by
`struct usb_request *`. Each slot contains only an atomic key and two `u64`
timestamps. Queue timestamping occurs immediately before `usb_ep_queue()`;
failed queues clear the pending timestamp. Completion looks up the request,
computes queue-to-completion latency and completion-to-next-queue gap, then
updates the existing telemetry sink. `usb_request->context`, skb lifetime,
request allocation/free order, callbacks, and existing datapath locks are not
changed. A full table or missing key produces an un-timestamped completion,
never a fabricated value.

The sink API was extended to accept latency, gap, and a validity flag. No
allocation, printk, timer, workqueue, USB registration, UDC access, or
configfs access was added to the telemetry path.

## Build and static audit

Both modules were rebuilt against the target vendor tree
`/home/masataka/projects/sbair6-rce/work/src/linux-5.4.238`, whose
`module_layout` CRC is `0x3a3eb6e9`, matching the known T6A vendor ABI.
The arm64 build completed without warnings. Candidate metadata is
`vermagic=5.4.238 SMP mod_unload modversions aarch64` and
`depends=sbat6_ncm_telemetry`; the completion symbol CRC is `0x35343bb1` in
both candidate and sink.

The fixed table is 64 slots (approximately 1.5 KiB). The added path has no
datapath lock and no hot-path allocation. A throughput overhead percentage was
not claimed because the end-to-end test did not complete.

## Live actions and incident

The standalone sink was loaded and unloaded successfully on T6A while the
original `usb_net` gadget remained `ncm0 UP/LOWER_UP`, UDC `configured`.

Loading the integrated candidate alongside the original `usb_net` was
correctly rejected because the NCM function was already registered. A
controlled replacement then removed the UDC binding, removed `f5`, unloaded
`usb_net`, loaded the sink and candidate, and attempted to recreate
`ncm.gs8`. The candidate did load, but its configfs instance did not expose the
vendor instance attributes; `f5` was not recreated. The rollback script also
failed to restore the link because it did not stop on the failed symlink
creation. The final observed state before management loss was:

- `usb_f_ncm` loaded
- `sbat6_ncm_telemetry` loaded as its dependency
- UDC `11201000.usb` reported `configured`
- `ncm0` absent
- config `b.1/f5` absent
- T6A `192.168.3.2` then became ARP-unreachable and SSH unavailable

No baseline iperf, telemetry interval, cause classification, first variable
change, or 1.50 Gbps claim was made. No flash, eFuse, ADB, or persistent
configuration operation was performed.

## Recovery requirement

Further SSH or module operations are not possible while T6A is unreachable.
The next recovery action must use an out-of-band console or a controlled
physical power-cycle, then restore the original vendor `usb_net` and the
saved `b.1/f5 -> ncm.gs8` configuration before any performance test.
