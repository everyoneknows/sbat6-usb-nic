# Structure offset comparison

Offline compilation used the candidate's Linux 5.4.238 headers and AArch64
kernel build configuration. The helper source and compiler-visible values are
recorded in the analysis work log; no module was loaded.

| object/member | candidate generic 5.4 | vendor evidence | result |
|---|---:|---:|---|
| `sizeof(struct usb_function_instance)` | `0xb0` | not directly recoverable | NOT_PROVEN |
| `sizeof(struct config_group)` | `0x88` | not directly recoverable | NOT_PROVEN |
| `sizeof(struct config_item)` | `0x50` | not directly recoverable | NOT_PROVEN |
| `sizeof(struct config_item_type)` | `0x28` | not directly recoverable | NOT_PROVEN |
| `sizeof(struct f_ncm_opts)` | `0x1b8` | allocation `0x1c0` at `0x1cc0` | **difference proven** |
| `sizeof(struct eth_dev)` | `0xb8` | not directly recoverable | NOT_PROVEN |
| `f_ncm_opts.net` | `+0xb0` | vendor setup result stored at `+0xb8` | likely mismatch |
| `f_ncm_opts.ncm_interf_group` | `+0xc0` | returned OS group stored at `+0xc8` | likely mismatch |
| `f_ncm_opts.ncm_os_desc` | `+0xc8` | vendor descriptor base is part of private layout | NOT_PROVEN |
| `f_ncm_opts.lock` | `+0x190` | mutex init at `+0x198` | **8-byte mismatch proven** |
| `f_ncm_opts.refcnt` | `+0x1b0` | not directly proven | NOT_PROVEN |

The vendor call passes the base object (`x19`) as the first argument to
`config_group_init_type_name`; this is consistent with `func_inst.group` at
the object base. The name and type arguments are prepared before the call, but
the type object's exact symbol cannot be recovered from the stripped local
pointer table.

The vendor `eth_dev` and kernel ConfigFS layouts cannot be fully reconstructed
from this single ELF because their definitions are external/private and the
compiler has folded several static objects. Do not treat unobserved members as
equal.
