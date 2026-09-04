# T6A NCM probeability audit and source instrumentation — 2026-09-04

## Scope

The audit used only `agent-101-vm -> raspi2 -> SSH root@192.168.3.2` with
the configured SSH identity. No ADB, raspi4, USB role change, UDC rebind,
reboot, persistent setting change, or eFuse/security operation was used.

## Live audit result

- T6A: Linux 5.4.238, aarch64; `ncm0` remains UP/LOWER_UP.
- `/proc/modules`: `usb_net` is loaded.
- `/lib/modules/5.4.238/usb_net.ko` exists; SHA256 is
  `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
- `/sys/module/usb_net/sections/*` exposes section addresses, including
  `__ksymtab_gpl` and `__param`; this does not expose safe private prototypes.
- `/proc/kallsyms` contains public MTU3 symbols and trace-event helpers, but
  the vendor NCM data-path functions are not usable as a complete prototype-
  checked hook interface. The saved object retains local `rx_fill` and
  `gether_connect` symbols.
- `debugfs` and `tracefs` are mounted, but `/sys/kernel/debug/kprobes` is
  absent. The kernel config reports `# CONFIG_KPROBES is not set` and
  `# CONFIG_FUNCTION_TRACER is not set`; only generic `CONFIG_FTRACE=y` is
  enabled. Therefore kprobe/ftrace function hooking is not available on the
  running kernel.
- `mtu3` is present in the saved `modules.builtin` as
  `drivers/usb/mtu3/mtu3.ko`; no replaceable live MTU3 module was found.

Decision: do not hook raw local addresses and do not infer a prototype from
register layout or disassembly alone. The requested probeability gate is
closed for automatic hooks; proceed with a vendor-source patch.

## Source-level step completed

The saved vendor source at `/home/user/projects/sbat6-usbnet/source/` was
instrumented with the existing counter sink interface:

- `u_ether.c`: exact `eth_start_xmit()` queue return and current TX queue
  depth immediately after `usb_ep_queue()`.
- `f_ncm.c`: exact final NTB length, fixed capacity, DPE count, timeout/full
  indication in `package_for_tx()`.
- `f_ncm.c`: exact `ncm_unwrap_ntb()` block length and total DPE count,
  elapsed unwrap time, and malformed/drop/error path count.
- Added `sbat6_ncm_telemetry.h` with only plain-value extern declarations.

No packet data, pointer, skb, request, endpoint, printk, tracepoint, timer,
allocation, or new lock was added to the telemetry calls. The sink remains a
separate module and is not automatically loaded by this patch.

## Build and static verification

Built against the saved vendor 5.4.238 kernel output and arm64 toolchain:

```text
make -C .../linux-5.4.238-ax88179 \
  O=.../tmp-kernel-out.yf9KMT M=.../sbat6-usbnet \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  KBUILD_EXTRA_SYMBOLS=.../butlerx/research/t6a-ncm-telemetry/Module.symvers modules
```

The build completed without compiler warnings or errors. Generated candidate:

`/home/user/projects/sbat6-usbnet/source/usb_f_ncm.ko`

Its module metadata records `depends=sbat6_ncm_telemetry`; all five called
telemetry symbols remain normal imports and match the sink's exported CRC
interface. The candidate was not loaded onto T6A. The live `usb_net` module
and gadget state are unchanged.

## Remaining instrumentation gap

This first source patch deliberately does not fabricate completion latency.
The current sink API needs a request-associated timestamp to provide exact
queue-to-completion latency; `usb_request->context` is occupied by the skb.
TX/RX completion counters and request timestamp association require one more
reviewed, per-request bookkeeping change before deployment. No false latency
values were emitted.

Next safe step is to add that bounded request timestamp bookkeeping, rebuild,
then perform an ABI/load smoke test and only afterward consider a controlled
module replacement and Windows 3-run baseline comparison.
