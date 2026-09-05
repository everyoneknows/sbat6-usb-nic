# T6A vendor `usb_net.ko` gadget queue reconstruction — 2026-09-04

## Scope

Read-only static analysis of the saved original vendor module and read-only
observation of T6A through the approved path `agent-101-vm -> raspi2 ->
T6A-MGMT-IP`. No ConfigFS, module, endpoint, trace, or tuning value was
changed.

Static object SHA256: `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
T6A kernel: `5.4.238`, UDC: `11201000.usb`, loaded module: `usb_net`.

## Reconstructed path

### FACT: ConfigFS value and vendor get/set pair

The live T6A tree contains `/config/usb_gadget/g1/functions/ncm.gs8/qmult`
with value `30`; the function is linked as `configs/b.1/f5` and exposes
`ifname=ncm0`. In the module, the qmult store paths parse an 8-bit value and
relocate to `gether_set_qmult` (`.text+0x60`); show paths relocate to
`gether_get_qmult` (`.text+0x68`). The pair stores/loads the same vendor
object field at offset `+2472`.

This proves ConfigFS -> vendor getter/setter storage/readback. It does not
prove that the connect-time allocation counts are loaded from that field.

### FACT: connect-time count calculation

`gether_connect` is a retained local symbol at `.text+0x3394`, section
`.text` (ELF symbol table entry size 892). After both bulk endpoints are
enabled, it loads a precursor from vendor state at `[.data+88]`, then:

```text
w26 = precursor
w4  = dev[454]                 # speed/packet-related byte
w27 = w26 / w4
if (.bss+0x24 != 0)
        w27 = min(.bss+0x24, w26)
w27 is stored at dev+456
w0  = (w27 << 1) / 3
w0 is stored at dev+460
```

The two allocation calls are:

```text
.text+0x3594 -> .text.unlikely+0x25c, endpoint at dev+232, count w26
.text+0x35dc -> .text.unlikely+0x25c, endpoint at dev+224, count w27
```

The assembly contains no `qmult * 2` operation and no vendor `DEFAULT_QLEN`
constant/helper. The visible `<<1` is applied to `w27` and then divided by
3 for a separate stored value; it is not the upstream queue-length formula.
The exact semantic names RX/TX for the two endpoint fields are inferred from
the endpoint direction and surrounding list setup: the `dev+232` call is the
OUT/RX side (`w26`), and `dev+224` is the IN/TX side (`w27`).

### FACT: request allocator and request-list object

The allocation helper is anonymous, `.text.unlikely+0x25c`, section
`.text.unlikely`; it has no symbol name. Its relocation/xref is recorded in
`.rela.text` at `.text+0x3594` and `.text+0x35dc`, and its ftrace/section
references are in `.rela__... entries` for `.text.unlikely+0x25c`.

The helper receives the count in `w3`. If zero, it returns an error. Otherwise
it decrements the count once per iteration, calls the imported
`usb_ep_alloc_request` once per iteration (`.text.unlikely+0x2c8`), and
links the resulting request into the supplied doubly-linked list. The request
list node is embedded at a fixed offset from the allocated vendor wrapper; the
link operations are visible at `.text.unlikely+0x340..0x358`.

Therefore the allocation totals are:

```text
RX allocated = w26 iterations, subject to allocation failure
TX allocated = w27 iterations, subject to allocation failure
```

The saved relocatable object does not contain the live values of the vendor
precursor, `.bss+0x24`, or `dev[454]`, so `w26` and `w27` cannot be
reduced to numbers from the binary alone.

### FACT: loaded-object address check

The live kernel exposes module section bases through `/sys/module/usb_net/sections`:

```text
.text          = 0xffffffc0097cc000
.text.unlikely = 0xffffffc0097d31e8
.data          = 0xffffffc0097dd000
.bss           = 0xffffffc0097dddc0
```

`/proc/kallsyms` resolves `gether_connect` to
`0xffffffc0097cf394` and `rx_fill` to `0xffffffc0097cef78`, exactly matching
the saved offsets `0x3394` and `0x2f78`. The anonymous allocator therefore
has the loaded address `0xffffffc0097d3444` (`.text.unlikely+0x25c`), though
it remains unnamed and its live argument registers are not externally
observable through kallsyms.

### FACT: queue calls and refill behavior

The module has multiple `usb_ep_alloc_request` and `usb_ep_queue` call
sites. The gadget data-path refill function is retained as `rx_fill` at
`.text+0x2f78`. It removes one wrapper from the RX free list, prepares its
buffer/bookkeeping, and calls `usb_ep_queue` at `.text+0x331c` once. It
then loops back to the free list and repeats while the list is non-empty and
the vendor limit at `.data+88` has not been reached.

`gether_connect` invokes `rx_fill` at `.text+0x3750` with buffer size
`0xcc0` after connect/state setup. Thus initial RX queueing is one
`usb_ep_queue` call per successfully prepared free-list entry, not one bulk
call containing the entire count.

Static evidence does not show a TX prequeue loop directly in
`gether_connect`. TX queueing occurs through later data-path call sites,
including the vendor NCM transmit path; the saved object does not expose a
source-level callback name for each site. Completion-to-requeue for RX is
established by the `rx_fill` refill loop and its callback-driven return to
that function. The exact TX completion callback and whether it immediately
requeues or returns to a deferred/vendor PPE path remains unresolved from
this object alone.

### FACT: live QMU observation, separate layer

The approved read-only path reached T6A and showed:

* `/sys/kernel/debug/usb/11201000.usb/eps/*/{qmu-gpd,qmu-ring}` exist.
* Active endpoint inventory included `ep1..ep9`; `ep5out` and `ep8in` were
  bulk, max packet 1024, slot 2, and their qmu-gpd views contained 64 ring
  entries. `ep5out` reported a 64-entry ring with `enq=start` and
  `dep=start+0x20`; `ep8in` reported a 64-entry ring with `enq=dep`.
* `ep5out` and `ep8in` each reported a 3 KiB FIFO (`seg_size=1024`).

These observations establish a read-only method for seeing MTU3 QMU ring
capacity/state. They do not establish the gadget request-list length or map
those endpoints uniquely to `ncm.gs8`; the live debugfs output has no function
name, and this gadget also contains ACM, ADB, and mass-storage functions.
Pointer equality in a circular ring is also not by itself a unique numeric
outstanding count without the controller's full/empty convention.

The 64-entry MTU3 GPD ring is controller DMA descriptor capacity/state.
Vendor `usb_request` wrappers and their TX/RX free/active lists are a
different layer. Neither 64 GPD entries nor host usbmon URB counts can be
converted into “60 gadget TX requests.”

## FACT / INFERENCE / UNKNOWN

### FACT

* `qmult=30` is live in ConfigFS and read back by the vendor function.
* Vendor `gether_connect` uses distinct counts `w26` and `w27`.
* The counts are passed to an anonymous allocator that performs one
  `usb_ep_alloc_request` per iteration and links requests into lists.
* `rx_fill` queues one request at a time and is called from connect.
* T6A exposes read-only MTU3 QMU/GPD debugfs state with 64 ring entries.

### INFERENCE

* The `dev+232/w26` allocator is RX/OUT and `dev+224/w27` is TX/IN, based on
  the endpoint arguments and subsequent list setup.
* `ep5out`/`ep8in` are plausible NCM bulk endpoints in the current composite
  gadget, but this is not uniquely established by the available debugfs
  labels.

### UNKNOWN

* Whether the live vendor precursor and speed byte evaluate to 60, or any
  other pair, for the current qmult=30.
* Whether qmult's stored field is read indirectly by the precursor path.
* Exact initial TX queue count at connect; no direct TX prequeue loop is in
  `gether_connect`.
* Exact live gadget TX outstanding request count.
* Exact TX completion callback/requeue path and its current deferred/PPE
  behavior.
* A unique mapping from NCM function to the current `ep5out`/`ep8in` names.

## Upstream comparison

Upstream `u_ether.c` has an explicit `DEFAULT_QLEN=2`; at High/SuperSpeed its
`qlen()` is `qmult * DEFAULT_QLEN`, and connect preallocates the same `n` on
TX and RX. Thus the upstream model predicts 60 TX + 60 RX = 120 requests at
qmult=30. The vendor binary instead has no corresponding named constant or
helper, computes two distinct count inputs, and adds vendor list bookkeeping,
PPE hooks, MTU3 integration, and NCM wrapping paths. The upstream 120-count
number is therefore a comparison baseline, not a T6A vendor fact.

## Decision

The success condition is not yet met: `qmult=30 -> exact vendor TX request
count` remains unresolved. No live tuning or data-path patch should be
started. The next authorized read-only step is to obtain a loaded-object
field map or an existing vendor debug/trace facility that exposes the two
allocator counts or request identities; otherwise the remaining proof
requires a minimal human-authorized observation mechanism on T6A.
