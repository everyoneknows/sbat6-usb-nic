# ABI review and pstore correspondence

The 2026-09-04 candidate used the generic representation and placed
`ncm_free_inst` at `+0xa8`. The vendor/MediaTek-family evidence places
`set_inst_name` at `+0xa8` and `free_func_inst` at `+0xb0`.

```text
20260904 candidate
+0xa8 = ncm_free_inst
          ↓
vendor expects set_inst_name
          ↓
directory-only
          ↓
attribute read
          ↓
__configfs_open_file NULL dereference
```

```text
20260905 compat candidate
+0xa0 = f
+0xa8 = set_inst_name(NULL)
+0xb0 = ncm_free_inst
```

This is a **high-confidence corrective candidate based on reproduced ABI
mismatch mechanism**. It does not by itself prove that the ABI mismatch is the
sole root cause of the reset/Oops.

The pstore evidence remains the reproduced `__configfs_open_file` NULL
derefence while reading an attribute. The live experiment remains blocked by
the explicit no-T6A-operation restriction.
