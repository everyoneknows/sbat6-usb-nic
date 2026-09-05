# Reproduction record

Kernel source/KDIR:
`../vendor-workspace/work/src/linux-5.4.238-ax88179`

Kernel output:
`./tmp-kernel-out.yf9KMT`

Architecture/toolchain: `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`

The candidate was built as an external composite module containing `f_ncm.o`
and `u_ether.o`, with `sbat6_ncm_telemetry` supplied through
`KBUILD_EXTRA_SYMBOLS`. The final ELF metadata is retained in `artifact-*`
and the original build command is retained in `build-command.txt`.

The vendor-kernel image `Module.symvers` was used for kernel symbols; the
telemetry sink `Module.symvers` was used for telemetry symbols. The complete
per-symbol comparison is retained in `abi-audit.tsv`. It reports no missing
or mismatched imported CRC for the map used at build time, but this does not
prove structural equivalence with private vendor source types.
