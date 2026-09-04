# T6A pstore preservation and analysis — 2026-09-05

## Preservation

The target was read through `agent-101-vm -> raspi2 -> root@192.168.3.2`.
No pstore file was removed, truncated, or otherwise modified.

| item | result |
|---|---|
| target collection time | 2026-09-05 04:43:56 JST |
| files | `console-ramoops-0` |
| target size | 262132 bytes |
| target SHA256 | `08dfbfd9ac55418bce97e914f80917e7ffd5c79e6493055327269c32d4edcf7f` |
| preserved raw | `console-ramoops-0.raw` |
| local raw SHA256 | same as target |
| transport archive | `raw/pstore.tar` |

The raw file and unmodified transport archive are retained here. The target
directory contained no `dmesg-ramoops-*` or `pmsg-ramoops-*` file.

## pstore result

The record contains a kernel Oops during the attribute-read phase:

```text
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000208
Internal error: Oops: 96000006 [#1] SMP
CPU: 2 PID: 26931 Comm: cat Tainted: P        W         5.4.238 #0
pc : __configfs_open_file.isra.0+0xb4/0x1b0
lr : __configfs_open_file.isra.0+0xa0/0x1b0
```

The trace continues through `do_dentry_open`, `path_openat`, `do_filp_open`,
and the arm64 syscall path. It is already symbolic; no absolute PC was
supplied for additional kallsyms/System.map resolution. The pstore does not
name `ncm_free_inst`, `function_make`, or `usb_put_function_instance`.

Repeated preceding USB port-enable failures are also present, but do not
explain the precise `cat`-context ConfigFS NULL dereference. The evidence
supports ConfigFS object/operation corruption during attribute open. It does
not alone prove the immediate callback target.

## Updated classification

- `USB_FUNCTION_INSTANCE_ABI_MISMATCH`: **high-confidence leading candidate**
- `WRONG_SET_INST_NAME_CALLBACK`: **high-confidence mechanism candidate**
- `USE_AFTER_FREE_AFTER_FUNCTION_MAKE`: **possible, not proven by this pstore**
- Low-level reset/watchdog trigger: **not proven**; the Oops is proven, while
  the later reboot/restart behavior remains separate from Oops causal proof.

Prior replay evidence establishes `mkdir RC=0`, directory-only visibility,
failure during `cat`, management interruption, short post-boot uptime,
`reboot_reason=3`, and pstore creation. This pstore upgrades the ConfigFS
fault to a proven kernel Oops, but not to a fully callback-symbolized proof.
