#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SRC=$ROOT/source
KO=${KO:-$ROOT/artifacts/usb_f_ncm.ko}
VENDOR_MAP=${VENDOR_MAP:-$ROOT/abi/vendor-kimage.Module.symvers}
TELEMETRY_MAP=${TELEMETRY_MAP:-/home/user/projects/butlerx/research/t6a-ncm-telemetry/Module.symvers}
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

# Import validation is based on the final ELF, not on a retained modpost
# input.  A layout/codegen change may legitimately change the import set.
UND=$(mktemp)
VERS=$(mktemp)
MODCRC=$(mktemp)
trap 'rm -f "$UND" "$VERS" "$MODCRC" ${DISASM:-}' EXIT
aarch64-linux-gnu-nm -u "$KO" | sed -n 's/^ *U //p' | sort -u >"$UND"
awk -F'"' '/\{ 0x[0-9a-fA-F]+, "/ { line=$1; sub(/^.*\{[[:space:]]*/,"",line); sub(/,[[:space:]]*$/, "", line); print tolower(line), $2 }' "$ROOT/source/usb_f_ncm.mod.c" | sort -u >"$MODCRC"
awk '{ print $2 }' "$MODCRC" | sort -u >"$VERS"

if [ "$(wc -l <"$UND")" -eq "$(wc -l <"$VERS")" ]; then
  pass "actual undefined symbols have __versions ($(wc -l <"$UND")/$(wc -l <"$VERS"))"
else
  fail "actual undefined symbols have __versions (UND=$(wc -l <"$UND"), versions=$(wc -l <"$VERS"))"
fi

# Import-set equality with the old candidate is informational only.  The
# mandatory condition is coverage of the imports actually present in this ELF.
OLD_KO=${OLD_KO:-$ROOT/../../../sbat6-usbnet/source/usb_f_ncm.ko}
old_und_count=$(aarch64-linux-gnu-nm -u "$OLD_KO" 2>/dev/null | sed -n 's/^ *U //p' | sort -u | wc -l)
old_version_count=$(grep -c '".*" }' "$ROOT/../../../sbat6-usbnet/source/usb_f_ncm.mod.c" 2>/dev/null || true)
printf '[INFO] old import-set equality is informational (old UND=%s, old __versions=%s)\n' "$old_und_count" "$old_version_count"

if [ -f "$VENDOR_MAP" ] && [ -f "$TELEMETRY_MAP" ]; then
  vendor_crc() { awk -v n="$1" '$2 == n { c=tolower($1); sub(/^0x0+/,"0x",c); print c; exit }' "$VENDOR_MAP"; }
  telemetry_crc() { awk -v n="$1" '$2 == n { c=tolower($1); sub(/^0x0+/,"0x",c); print c; exit }' "$TELEMETRY_MAP"; }
  kernel_total=0; kernel_match=0; telemetry_total=0; telemetry_match=0; missing=0
  while IFS= read -r sym; do
    case "$sym" in
      sbat6_ncm_*)
        telemetry_total=$((telemetry_total + 1))
        crc=$(awk -v n="$sym" '$2 == n { c=$1; sub(/^0x0+/,"0x",c); print c; exit }' "$MODCRC" 2>/dev/null || true)
        expected=$(telemetry_crc "$sym")
        [ -n "$crc" ] && [ "$crc" = "$expected" ] && telemetry_match=$((telemetry_match + 1)) || missing=1
        ;;
      *)
        kernel_total=$((kernel_total + 1))
        crc=$(awk -v n="$sym" '$2 == n { c=$1; sub(/^0x0+/,"0x",c); print c; exit }' "$MODCRC" 2>/dev/null || true)
        expected=$(vendor_crc "$sym")
        [ -n "$crc" ] && [ "$crc" = "$expected" ] && kernel_match=$((kernel_match + 1)) || missing=1
        ;;
    esac
  done <"$UND"
  [ "$missing" -eq 0 ] && pass "actual kernel import CRCs match vendor map ($kernel_match/$kernel_total)" || fail "actual kernel import CRCs match vendor map ($kernel_match/$kernel_total)"
  [ "$telemetry_match" -eq "$telemetry_total" ] && pass "telemetry CRCs exact ($telemetry_match/$telemetry_total)" || fail "telemetry CRCs exact ($telemetry_match/$telemetry_total)"
else
  fail 'vendor and telemetry CRC inputs present'
fi

grep -q '"module_layout"' "$ROOT/source/usb_f_ncm.mod.c" &&
  awk '$2 == "module_layout" { exit (tolower($1) == "0x3a3eb6e9" ? 0 : 1) } END { if (NR == 0) exit 1 }' "$VENDOR_MAP" &&
  pass 'module_layout exact = 0x3a3eb6e9' || fail 'module_layout exact = 0x3a3eb6e9'

if command -v aarch64-linux-gnu-objdump >/dev/null 2>&1; then
  DISASM=$(mktemp)
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
if diff -q "$SRC/u_ether.c" "$ROOT/../20260904/source/u_ether.c" >/dev/null 2>&1 &&
   diff -q "$SRC/sbat6_ncm_telemetry.h" "$ROOT/../20260904/source/sbat6_ncm_telemetry.h" >/dev/null 2>&1; then
  pass 'no performance/datapath source changes'
else
  fail 'no performance/datapath source changes'
fi

printf 'RESULT=%s\n' "$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
