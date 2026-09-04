# Candidate/vendor static diff

| area | vendor ELF | candidate | assessment |
|---|---|---|---|
| `ncm_alloc_inst` symbol | absent from normal `.symtab`; code inferred at `0x1c7c` | source function present | symbol retention difference |
| allocation | `0x1c0` | `sizeof(struct f_ncm_opts)=0x1b8` | STRUCT_ABI_MISMATCH |
| mutex | `opts+0x198` | `opts+0x190` | STRUCT_ABI_MISMATCH |
| free callback | store in instance object; exact pointer target unnamed | `free_func_inst=ncm_free_inst` | lifecycle shape matches, target not fully proven |
| gether setup | `gether_setup_name_default` | `gether_setup_default` → name `usb` | semantically equivalent call path |
| ConfigFS init | present at `0x1d8c` | present in source | no missing call |
| OS descriptor | present at `0x1da8`, count 1 | present in source, count 1 | no missing call |
| attrs | four names proven in strings | `dev_addr`, `host_addr`, `qmult`, `ifname` | likely same; pointer table not proven |
| netdev registration | helper exists at `0x714`; not in instance routine | bind path calls registration | lifecycle stage differs, expected |
| gether implementation | vendor private MTK/PPE hooks and extensions | generic 5.4 plus candidate telemetry | U_ETHER_DEPENDENCY remains possible |

## Classification

- **A STRUCT_ABI_MISMATCH — high confidence for an internal layout difference.**
  The `0x1c0` allocation and `+0x198` mutex store are direct disassembly facts
  versus candidate `0x1b8`/`+0x190`.
- **B VENDOR_LIFECYCLE_DIFFERENCE — not proven.** The ordering is materially
  the same; private cleanup and additional fields may still matter.
- **C CONFIGFS_TYPE_MISMATCH — plausible, not proven.** The call exists and the
  four attribute names exist, but the vendor `ct_attrs` pointer/type object
  cannot be identified with normal symbols.
- **D U_ETHER_DEPENDENCY — plausible secondary factor.** Vendor gether contains
  MTK/PPE-specific hooks; this ELF does not prove they cause empty attributes.
- **E NOT_PROVEN — required for exact callback/type identity and full layout.**

Overall confidence: **medium-high** that the generic candidate cannot be
ABI-equivalent to this vendor private object; **medium** for the explanation of
the empty ConfigFS directory; **low** for selecting a single final root cause
from ELF alone.

## Design direction (not implemented)

Do not patch by padding guessed fields. First obtain matching vendor headers or
reconstruct the complete private `f_ncm_opts`/ConfigFS type objects. Then make
the candidate use an explicitly documented vendor-compatible layout and test
the `ct_attrs` pointer and lifecycle offline before any hardware load.
