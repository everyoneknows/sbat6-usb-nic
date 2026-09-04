# T6A vendor NCM qmult/request follow-up audit — 2026-09-04

## Scope and safety

This is a read-only audit of the saved vendor module
`analysis/t6a-usb_net/usb_net.ko`, SHA256
`271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
No device, ConfigFS object, module, endpoint, or tuning parameter was changed.
The recent `rx_max` and IRQ-affinity A/B results remain recorded and excluded
from the priority candidates. No memcpy/CRC/NTB patch was made.

## Answers

### 1. `DEFAULT_QLEN=2`

The saved upstream source contains the exact upstream definition
`#define DEFAULT_QLEN 2` and the `qlen()` helper. The vendor ELF has no
`DEFAULT_QLEN`, `qlen`, `prealloc`, or `alloc_requests` symbol/string that
would prove the same named implementation. Therefore the vendor module does
**not** provide evidence of the upstream constant as such.

It does contain an allocation helper at `.text.unlikely+0x25c` (not retained
as a symbol). This helper receives a count, decrements it in a loop, calls
`usb_ep_alloc_request()` once per iteration, and links each request onto a
list. That is an allocation-count mechanism, but not proof of the upstream
constant or formula.

### 2. High/SuperSpeed `qmult * DEFAULT_QLEN`

Upstream: `qlen()` returns `qmult * 2` at High/SuperSpeed and
`alloc_requests()` passes the same result to both TX and RX `prealloc()` calls.

Vendor: `gether_connect` at `.text+0x3394` enables both bulk endpoints and then
passes **different count registers** to the allocation helper: RX/out receives
`w26` at `.text+0x3584`, while TX/in receives `w27` at `.text+0x35d4`.
Before those calls the vendor code derives values using a speed-dependent
byte and stores values at offsets `+456` and `+460`; the visible arithmetic is
not the upstream `qmult * 2` operation.

**Conclusion:** High/SuperSpeed `qmult * DEFAULT_QLEN` is not confirmed for
the vendor module; the observed vendor connect path is materially different.

### 3. ConfigFS qmult propagation

The vendor ELF contains three ConfigFS qmult paths (NCM/ECM/RNDIS-shaped
copies). Each path parses an 8-bit value with `kstrtou8`, calls
`gether_set_qmult` (for example relocation `.text+0x3a14`), and its show path
calls `gether_get_qmult` (for example `.text+0x3a64`). Vendor
`gether_set_qmult` stores the value at input object offset `+2472`; the getter
loads that same offset. Thus ConfigFS readback proves storage and retrieval
through the vendor get/set pair.

What is **not** proven is that the connect-time count inputs `w26/w27` are
loaded from that stored field. The connect path loads its count precursor from
another vendor object/global offset and applies additional arithmetic. This
is the precise broken link in the former assumption that ConfigFS `30`
implies `60+60`.

### 4. Requests allocated at connect/open

The vendor helper at `.text.unlikely+0x25c` allocates one request per loop
iteration with `usb_ep_alloc_request()` and links it to the supplied list.
`gether_connect` invokes it once for RX and once for TX, with counts `w26` and
`w27` respectively. The exact runtime values of `w26/w27` are not recoverable
from the saved relocatable module without the loaded vendor object state and
field mapping. The module has multiple later `usb_ep_queue()` sites; the RX
refill function at `rx_fill` (`.text+0x2f78`) queues requests one at a time.

### 5. Theoretical count at qmult=30

For upstream semantics: High/SuperSpeed gives `n=30*2=60` per direction,
so 120 gadget-side request objects in total (60 TX + 60 RX), before any
allocation failure or later queue-state change.

For the vendor module: **not numerically determined** from ConfigFS `30`.
The only defensible statement is `TX=w27`, `RX=w26` at the two connect calls;
neither has been proven equal to 60. ConfigFS display `30` is not request
evidence.

### 6. Read-only runtime observation

The saved evidence proves no existing read-only interface that directly
reports the vendor `tx_reqs`/`rx_reqs` list lengths. Host usbmon can show host
URBs, but cannot prove gadget-side request-pool size. MTU3 debug/QMU counters,
if exposed on the T6A, can show controller outstanding descriptors but are a
different layer. A valid proof requires an existing vendor debugfs counter/list
dump, a tracepoint that records allocation/queue identity, or a read-only
privileged inspection path on the running kernel. The earlier T6A SSH
authentication failure means this proof was not collected in this pass.

### 7. MTU3 GPD ring versus u_ether requests

These are separate quantities:

* MTU3's 64-entry GPD ring is a controller DMA descriptor/ring capacity.
* `tx_reqs` and `rx_reqs` are gadget-layer `struct usb_request` objects and
  their free/active lists.

A 64-entry host/controller observation cannot be converted into 60 gadget
TX requests. Conversely, a gadget request count does not establish 64 GPDs.

### 8. Concrete upstream versus vendor differences

* Upstream has explicit `DEFAULT_QLEN=2`, a speed predicate, and
  `qlen=qmult*2` at High/SuperSpeed. Vendor has no corresponding named
  constant/helper evidence.
* Upstream calls one `alloc_requests(dev, link, n)` which preallocates the
  same `n` on TX and RX. Vendor calls an anonymous allocator with distinct
  RX/TX count registers `w26/w27`.
* Upstream `prealloc()` maintains a bounded free list and allocates exactly
  the missing entries up to `n`. Vendor's recovered helper allocates its
  supplied count directly while traversing/inserting vendor lists; the
  surrounding list/field layout is vendor-specific.
* Upstream RX uses `rx_fill()` to take every free RX request, attach an skb,
  and call `usb_ep_queue(out, req, ...)`; vendor has a separate `rx_fill`
  implementation with vendor bookkeeping, allocation and the same external
  `usb_ep_queue` primitive.
* Vendor adds PPE hooks (`ppe_usb_tx_link_num_hook`, `ppe_usb_tx_done_hook`,
  `ppe_usb_rx_send_hook`, suspend/resume hooks), MTU3/vendor bookkeeping, and
  vendor NCM wrapping paths. These are outside upstream u_ether's minimal
  request/list layer.
* Vendor's NCM path has the previously recorded 16 KiB NTB parameters and
  payload-copy/CRC/allocation behavior; these are performance differences,
  but remain out of scope for new patching until request depth is proven.

## Audit decision

The original hypothesis “qmult=30 means 60 requests per direction” is valid
only for the upstream model, not for the running vendor module. The decisive
next requirement is a read-only T6A-side observation or a loaded-object
field-map that resolves `w26/w27`; no live tuning or data-path patch is
authorized by this audit result.
