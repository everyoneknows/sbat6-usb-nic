# Vendor `ncm_alloc_inst()` reconstruction

## Evidence

- Input: `../vendor/usb_net.ko` (AArch64 relocatable ELF, not stripped)
- SHA256: `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`
- The normal ELF symbol `ncm_alloc_inst` is **absent**. Only `ncm_mod_init` and
  `ncm_mod_exit` remain in `.symtab`; the function-name strings are present in
  `__ksymtab_strings`/`.rodata`.
- The NCM instance routine is nevertheless identifiable at `.text+0x1c7c`
  from its allocation size, mutex setup, `gether_setup_name_default`, ConfigFS
  initialization and OS-descriptor call. The complete extracted range is in
  `vendor-ncm-alloc-inst.disasm.txt`.

## Recovered order (vendor)

1. `kmem_cache_alloc_trace(..., 0xdc0, 0x1c0)`; NULL returns `-ENOMEM`.
2. Stores an internal pointer at `opts+0xd0`, initializes a mutex at `opts+0x198`.
3. Sets the instance free callback at `opts+0xb0` and calls
   `gether_setup_name_default()`; error frees the allocation.
4. Initializes list/group-related fields and calls
   `config_group_init_type_name()` at `0x1d8c`.
5. Calls `usb_os_desc_prepare_interf_dir()` at `0x1da8` with count 1 and
   stack-built descriptor/name arrays; error calls the vendor free path.
6. Stores the returned interface group at `opts+0xc8` and returns the instance.

The recovered sequence is therefore structurally the expected lifecycle, but
its offsets and object size are not the generic 5.4 candidate offsets.

## Candidate comparison

The candidate source follows the upstream 5.4 sequence: kzalloc `sizeof(*opts)`,
sets `opts->ncm_os_desc.ext_compat_id`, mutex, `free_func_inst`,
`gether_setup_default()`, ext_prop list, `config_group_init_type_name`, then
OS descriptor preparation and error cleanup. It also has the same four generic
ConfigFS attributes. No candidate-only missing lifecycle step was found.

The decisive observed difference is the vendor's private layout: its instance
allocation is `0x1c0`, while the candidate's compiled `struct f_ncm_opts` is
`0x1b8`; the vendor mutex is at `+0x198`, candidate `+0x190`. This is evidence
of an 8-byte tail/layout addition or a different private header, not proof that
the vendor and candidate structures are otherwise identical.

## Limits

Because `ncm_alloc_inst`, `ncm_free_inst`, `ncm_func_type`, and `ncm_attrs` are
not retained as normal symbols, ELF alone cannot name every pointer-table
target with certainty. The call sites and offsets are proven; exact callback
identity is inferred from the unique lifecycle pattern and relocation table.
