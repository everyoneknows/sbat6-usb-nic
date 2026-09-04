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
static gate reports `RESULT=FAIL`. The vendor map is demonstrably used only
after the isolated `vmlinux` input is disabled, but the diagnostic ELF has 72
imports instead of the old 74 and lacks `__stack_chk_fail` and
`kmem_cache_alloc_trace`. Strict modpost also rejects vendor-map-missing
symbols.
