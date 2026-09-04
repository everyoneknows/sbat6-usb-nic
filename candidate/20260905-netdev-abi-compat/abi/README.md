The candidate was checked against the vendor kernel-image map used by the
build. Required imported CRCs, including `module_layout`, matched that map;
the full generated comparison is `abi-audit.tsv`. This is an ABI-symbol check,
not proof that private vendor C structures or implementations are compatible.
