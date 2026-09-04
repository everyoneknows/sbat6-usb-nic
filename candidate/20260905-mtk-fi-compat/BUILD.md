# Reproduction record

Kernel source/KDIR:
`/home/masataka/projects/sbair6-rce/work/src/linux-5.4.238-ax88179`

Kernel output (isolated copy; original untouched):
`/home/masataka/projects/sbat6-usbnet/tmp-kernel-out.vendorcrc-20260905`

Architecture/toolchain: `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`

The candidate was built as an external composite module containing `f_ncm.o`
and `u_ether.o`, with `sbat6_ncm_telemetry` supplied through
`KBUILD_EXTRA_SYMBOLS`. The final ELF metadata is retained in `static/`
and the original build command is retained in `build-command.txt`.

The isolated output's original `Module.symvers` was saved as
`Module.symvers.upstream-original`, then replaced byte-for-byte with the
authoritative vendor map (SHA256
`0ded7d902226ff5ad15e2b9a1c82946c1463f9a93376fe478990c6c7a68883e7`).
Telemetry was supplied only through `KBUILD_EXTRA_SYMBOLS`.

With `vmlinux` present, modpost emitted upstream CRCs despite the swapped
map. After reversibly renaming that isolated file to
`vmlinux.modpost-disabled`, modpost emitted vendor CRCs for all 72 common
imports, but strict modpost stopped on vendor-map-missing symbols. The
diagnostic ELF therefore has 72 imports rather than the old 74; the two
missing old imports are `__stack_chk_fail` and `kmem_cache_alloc_trace`.
All 72 common CRCs are identical. The complete comparison is in
`static/crc-74-compare.tsv`.

RESULT remains FAIL. No deployable artifact was saved under `artifacts/`, and
no T6A operation was performed.
