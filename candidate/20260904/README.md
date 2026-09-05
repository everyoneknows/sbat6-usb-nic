# Candidate package: 2026-09-04 T6A load

This directory is the System-of-Record package for the exact `usb_f_ncm.ko`
loaded during the aborted T6A A1 attempt. It is offline evidence only; no
script here loads a module or changes a target.

The binary loaded on T6A is SHA256
`d2257ff360fa82c6f2ea639a9856ebd5db7e018b1e71c1113eb74e48ffe7e783`.
The matching source and build inputs are retained under `source/` and
`build/`; the independent hash manifest is `SHA256SUMS`.

## Provenance boundary

The candidate source is the saved Linux 5.4.238 `f_ncm.c`/`u_ether.c` from
`../vendor-workspace/work/src/linux-5.4.238-ax88179`, with
telemetry edits. It is **not** the source of the running vendor `usb_net.ko`.
The vendor ELF identifies its original path as:

`/home/yhchin/Work/Projects/Keyonet/Rudolf/01_release/sdk.mtk.quectel.rg620t/T830/openwrt/build_dir/target-aarch64-openwrt-linux-musl_musl/linux-gem6xxx_evb6990_cpe_mt7990_emmc/usb_net/f_ncm.c`

That source tree is not present on the build host. The vendor module itself is
retained as `vendor/usb_net.ko`; its ELF, strings, local symbols and CRCs are
the available substitute evidence. The absence of the vendor source is an
explicit limitation, not an assertion that the two implementations match.

## Direct cause assessment

The candidate ELF and source contain the complete normal ConfigFS lifecycle:
four attributes in `ncm_attrs`, `ncm_func_type.ct_attrs`, `ncm_alloc_inst`,
`gether_setup_default`, `config_group_init_type_name`, OS descriptor setup,
`ncm_alloc`, and `DECLARE_USB_FUNCTION_INIT`. Therefore the empty directory
cannot be explained by a missing candidate attribute table.

The direct source-level mismatch that is proven is that the candidate clones
the generic upstream 5.4 implementation while the live vendor provider is a
different, monolithic vendor implementation. The vendor ELF has vendor-only
helpers/CRCs and an internal `gether` implementation; its source path is
different. The exact failing runtime mechanism remains **not proven offline**
because the vendor source and a kernel-side dump of the registered type are
unavailable. `ncm0` is created by `gether_register_netdev()` during bind, so it
was absent because bind never completed after the empty instance; it is not a
host-enumeration prerequisite.

`restart_usb.sh` is a secondary rollback/watchdog: the retained live evidence
shows that missing `/dev/usb-ffs/adb/ep1` causes `/etc/init.d/usb.init start`,
which restores vendor `usb_net`. It is not the primary explanation for the
candidate's empty instance.

## Gate

Run from the repository root:

```sh
./audit/static-abi-gate.sh
```

This checks source lifecycle, ELF symbols, vermagic, dependency and the
absence of performance tuning. It is intentionally not a live ConfigFS test.
