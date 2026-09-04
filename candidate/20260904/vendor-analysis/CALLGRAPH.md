# Vendor NCM call graph

## Registration path

`ncm_mod_init (0x71a8)` → `usb_function_register` → vendor NCM
`usb_function_driver` table → inferred `ncm_alloc_inst` / `ncm_alloc`.

`ncm_mod_exit (0x71c8)` → `usb_function_unregister`.

The driver table is referenced through data relocations, but the local static
table symbol is not retained. Its name string `ncm` and the module init/exit
pair are present. Registration is therefore proven; individual table member
offsets are not fully proven.

## Instance path

`ncm_alloc_inst` (inferred `.text+0x1c7c`)
→ allocation (`0x1c0`)
→ `__mutex_init`
→ `gether_setup_name_default`
→ `config_group_init_type_name` (`0x1d8c`)
→ `usb_os_desc_prepare_interf_dir` (`0x1da8`)
→ return / vendor cleanup on error.

## Function/bind path

The vendor ELF contains the common gether operations, including
`gether_register_netdev` (`0x714`), but no direct call from the recovered
instance routine. As in generic gadget code, netdev registration belongs to
the function bind/activation path, not ConfigFS instance creation. Thus an
empty `ncm.gs8` before UDC bind does not contradict the absence of `ncm0`.

## Attribute path

The strings `dev_addr`, `host_addr`, `qmult`, and `ifname` are present. Their
pointer-table ownership and `ct_attrs` address are not symbolically recoverable
from this ELF. The four names are consistent with the generic attribute set;
no additional vendor NCM attribute was proven.
