# 2026-09-05 MediaTek-family function-instance compatibility candidate

This is an offline corrective candidate based on `candidate/20260904`. The
only intended semantic change is the private `sbat6_usb_function_instance_mtk`
representation in `source/u_ncm.h`, with generic API conversions centralized in
`to_sbat6_fi()` and `from_sbat6_fi()`.

The generic kernel header `include/linux/usb/composite.h` was not modified.
No NCM sizing, queueing, descriptors, burst settings, telemetry, or
`u_ether` datapath changes were made.

The compiled layout is:

| member | offset |
|---|---:|
| `group` | `0x00` |
| `cfs_list` | `0x88` |
| `fd` | `0x98` |
| `f` | `0xa0` |
| `set_inst_name` | `0xa8` |
| `free_func_inst` | `0xb0` |
| compat instance size | `0xb8` |
| `f_ncm_opts.net` | `0xb8` |
| `f_ncm_opts.ncm_interf_group` | `0xc8` |
| `f_ncm_opts.lock` | `0x198` |
| `f_ncm_opts` size | `0x1c0` |

The ELF disassembly records `+0xb0 = ncm_free_inst` and no assignment to
`+0xa8`; zero initialization therefore leaves `f` and `set_inst_name` NULL.

The artifact build is offline and is not approved for T6A deployment. The
static gate reports `RESULT=FAIL`. Import-set equality with the old candidate
is informational only. Direct extraction from the final diagnostic ELF found
81 undefined symbols and 72 `__versions` entries. The old ELF has 73 direct
undefined symbols and 74 `__versions` entries (the extra entry is
`module_layout`). The new ELF does not reference `__stack_chk_fail` or
`kmem_cache_alloc_trace`, but it has ten other actual kernel imports without
`__versions`: `hrtimer_init`, `kmem_cache_alloc`, and the eight `usb_ep_*`
symbols. Consequently the mandatory actual-import coverage gate fails;
64/74 kernel CRCs match, while all 7/7 telemetry CRCs match. The diagnostic
ELF is retained under `artifacts/` for audit only.
