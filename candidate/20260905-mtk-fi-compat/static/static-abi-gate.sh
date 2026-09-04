#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SRC=$ROOT/source
KO=${KO:-$ROOT/artifacts/usb_f_ncm.ko}
VENDOR_MAP=${VENDOR_MAP:-$ROOT/abi/vendor-kimage.Module.symvers}
TELEMETRY_MAP=${TELEMETRY_MAP:-/home/masataka/projects/butlerx/research/t6a-ncm-telemetry/Module.symvers}
fail=0
pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; fail=1; }
has() { grep -R -q -- "$2" "$1" && pass "$3" || fail "$3"; }

[ -f "$KO" ] && pass 'candidate artifact exists' || fail 'candidate artifact exists'
[ -f "$SRC/f_ncm.c" ] && pass 'candidate f_ncm.c exists' || fail 'candidate f_ncm.c exists'
[ -f "$SRC/u_ether.c" ] && pass 'candidate exact u_ether.c exists' || fail 'candidate exact u_ether.c exists'

has "$SRC/u_ncm.h" 'sizeof(struct sbat6_usb_function_instance_mtk) == 0xb8' 'compat instance sizeof = 0xb8'
has "$SRC/u_ncm.h" 'offsetof(struct sbat6_usb_function_instance_mtk, fd) == 0x98' 'fd = +0x98'
has "$SRC/u_ncm.h" 'offsetof(struct sbat6_usb_function_instance_mtk, f) == 0xa0' 'f = +0xa0'
has "$SRC/u_ncm.h" 'set_inst_name) == 0xa8' 'set_inst_name = +0xa8'
has "$SRC/u_ncm.h" 'free_func_inst) == 0xb0' 'free_func_inst = +0xb0'
has "$SRC/u_ncm.h" 'sizeof(struct f_ncm_opts) == 0x1c0' 'f_ncm_opts sizeof = 0x1c0'
has "$SRC/u_ncm.h" 'offsetof(struct f_ncm_opts, net) == 0xb8' 'net = +0xb8'
has "$SRC/u_ncm.h" 'ncm_interf_group) == 0xc8' 'ncm_interf_group = +0xc8'
has "$SRC/u_ncm.h" 'lock) == 0x198' 'mutex = +0x198'

has "$SRC/f_ncm.c" 'ct_attrs.*ncm_attrs' 'ct_attrs = +0x18 source ABI retained'
for attr in dev_addr host_addr qmult ifname; do
  has "$SRC/f_ncm.c" "$attr" "NCM attribute: $attr"
done
has "$SRC/f_ncm.c" 'DECLARE_USB_FUNCTION_INIT(ncm, ncm_alloc_inst, ncm_alloc)' 'usb_function_driver allocation ABI retained'
has "$SRC/f_ncm.c" 'free_func_inst = ncm_free_inst' 'free callback source assignment'
has "$SRC/f_ncm.c" 'to_sbat6_fi' 'generic boundary casts centralized'

if command -v aarch64-linux-gnu-objdump >/dev/null 2>&1; then
  DISASM=$(mktemp)
  trap 'rm -f "$DISASM"' EXIT
  aarch64-linux-gnu-objdump -dr "$KO" >"$DISASM"
  grep -A110 '<ncm_alloc_inst>:' "$DISASM" | grep -q 'str.*\[x19, #176\]' && pass 'ELF +0xb0 points to ncm_free_inst' || fail 'ELF +0xb0 points to ncm_free_inst'
  if grep -A110 '<ncm_alloc_inst>:' "$DISASM" | grep -q 'str.*\[x19, #168\]'; then
    fail 'ELF +0xa8 is NULL / no ncm_free_inst assignment'
  else
    pass 'ELF +0xa8 is NULL / no ncm_free_inst assignment'
  fi
else
  fail 'AArch64 objdump available for callback proof'
fi

readelf -p .modinfo "$KO" | grep -q 'vermagic=5.4.238 SMP mod_unload modversions aarch64' && pass 'vermagic exact' || fail 'vermagic exact'
readelf -p .modinfo "$KO" | grep -q 'depends=sbat6_ncm_telemetry' && pass 'telemetry dependency exact' || fail 'telemetry dependency exact'
MODVERSIONS=${MODVERSIONS:-$ROOT/static/modversions.c.txt}
if [ -f "$VENDOR_MAP" ] && [ -f "$TELEMETRY_MAP" ] && [ -f "$MODVERSIONS" ]; then
  awk -v vendor="$VENDOR_MAP" -v telemetry="$TELEMETRY_MAP" '
    function load(map,  l,n,a,c) {
      while ((getline l < map) > 0) { n=split(l,a,/[[:space:]]+/); if (n >= 2) { c=tolower(a[1]); sub(/^0x0+/,"0x",c); v[a[2]]=c } }
      close(map)
    }
    BEGIN { load(vendor); load(telemetry) }
    /\{ 0x[0-9a-f]+, "/ { line=$0; sub(/^.*\{ /,"",line); split(line,a,/[, ]+/); c=tolower(a[1]); sub(/^0x0+/,"0x",c); split($0,q,/"/); if (!(q[2] in v) || c != v[q[2]]) bad=1 }
    END { exit bad ? 1 : 0 }
  ' "$MODVERSIONS" && pass 'required symbol CRCs exact' || fail 'required symbol CRCs exact'
else
  fail 'required symbol CRC inputs present'
fi

if diff -q "$SRC/u_ether.c" "$ROOT/../20260904/source/u_ether.c" >/dev/null 2>&1 &&
   diff -q "$SRC/sbat6_ncm_telemetry.h" "$ROOT/../20260904/source/sbat6_ncm_telemetry.h" >/dev/null 2>&1; then
  pass 'no performance/datapath source changes'
else
  fail 'no performance/datapath source changes'
fi

printf 'RESULT=%s\n' "$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
