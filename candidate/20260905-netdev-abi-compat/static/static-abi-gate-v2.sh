#!/bin/sh
# Published MAC addresses are examples; set them to your local configuration before use.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
KO=${KO:-$ROOT/usb_f_ncm-netdev-abi-rebuilt.ko}
MODC=${MODC:-$ROOT/static/usb_f_ncm-rebuilt.mod.c}
VENDOR_MAP=${VENDOR_MAP:-$ROOT/../20260905-mtk-fi-compat/abi/vendor-kimage-extended.Module.symvers}
TELEMETRY_MAP=${TELEMETRY_MAP:-/home/user/projects/butlerx/research/t6a-ncm-telemetry/Module.symvers}
WORK=$(mktemp -d)
trap 'find "$WORK" -depth -delete' EXIT
fail=0
pass() { printf '[PASS] %s\n' "$1"; }
bad() { printf '[FAIL] %s\n' "$1"; fail=1; }

[ -s "$KO" ] && pass 'rebuilt final ELF exists' || bad 'rebuilt final ELF exists'
[ -s "$MODC" ] && pass 'rebuilt generated mod.c exists' || bad 'rebuilt generated mod.c exists'
[ -s "$VENDOR_MAP" ] && pass 'extended vendor map exists' || bad 'extended vendor map exists'
[ "$(sha256sum "$VENDOR_MAP" | awk '{print $1}')" = b259e638ada0a638c3b0142e1bb7ee604b9e5d718dd944615175f2c9d74a041a ] && pass 'extended vendor map SHA256 exact' || bad 'extended vendor map SHA256 exact'

# nm is the authoritative final-ELF import list; readelf is independently
# collected as a required cross-check of the ELF symbol table.
aarch64-linux-gnu-nm -u "$KO" | sed -n 's/^ *U //p' | sort -u >"$WORK/und.nm"
readelf -Ws "$KO" >"$WORK/readelf-Ws"
awk '$7 == "UND" && $8 != "" {print $8}' "$WORK/readelf-Ws" | sort -u >"$WORK/und.readelf"
diff -u "$WORK/und.nm" "$WORK/und.readelf" >"$WORK/und.diff" || true
if cmp -s "$WORK/und.nm" "$WORK/und.readelf"; then pass 'nm -u and readelf -Ws UND sets agree'; else bad 'nm -u and readelf -Ws UND sets agree'; fi

awk -F'"' '/\{ 0x[0-9a-fA-F]+, "/ {print $2}' "$MODC" | sort -u >"$WORK/versions"
grep -qx module_layout "$WORK/versions" && pass 'module_layout version record present' || bad 'module_layout version record present'
grep -vx module_layout "$WORK/versions" >"$WORK/versions.no-layout" || true
if cmp -s "$WORK/und.nm" "$WORK/versions.no-layout"; then
  pass "actual UND == versioned imports excluding module_layout (UND=$(wc -l <"$WORK/und.nm"), versions=$(wc -l <"$WORK/versions"))"
else
  bad 'actual UND == versioned imports excluding module_layout'
  printf '[DETAIL] UND-only:\n'; comm -23 "$WORK/und.nm" "$WORK/versions.no-layout"
  printf '[DETAIL] version-only:\n'; comm -13 "$WORK/und.nm" "$WORK/versions.no-layout"
fi

vendor_crc() { awk -v n="$1" '$2 == n {c=tolower($1); sub(/^0x0+/,"0x",c); print c; exit}' "$VENDOR_MAP"; }
telemetry_crc() { awk -v n="$1" '$2 == n {c=tolower($1); sub(/^0x0+/,"0x",c); print c; exit}' "$TELEMETRY_MAP"; }
mod_crc() {
  sed -n 's/.*{[[:space:]]*\(0x[0-9a-fA-F]*\),[[:space:]]*"\([^"]*\)".*/\1\t\2/p' "$MODC" |
    awk -F '\t' -v n="$1" '$2 == n {c=tolower($1); sub(/^0x0+/,"0x",c); print c; exit}'
}
kernel_total=0; kernel_match=0; telemetry_total=0; telemetry_match=0
: >"$WORK/kernel-crc.tsv"; : >"$WORK/telemetry-crc.tsv"
while IFS= read -r sym; do
  crc=$(mod_crc "$sym")
  if [ "$sym" = module_layout ]; then continue; fi
  if case "$sym" in sbat6_ncm_*) true;; *) false;; esac; then
    telemetry_total=$((telemetry_total + 1)); expected=$(telemetry_crc "$sym")
    if [ -n "$expected" ] && [ "$crc" = "$expected" ]; then result=MATCH; telemetry_match=$((telemetry_match + 1)); else result=FAIL; fi
    printf '%s\t%s\t%s\t%s\n' "$sym" "$crc" "$expected" "$result" >>"$WORK/telemetry-crc.tsv"
  else
    kernel_total=$((kernel_total + 1)); expected=$(vendor_crc "$sym")
    if [ -n "$expected" ] && [ "$crc" = "$expected" ]; then result=MATCH; kernel_match=$((kernel_match + 1)); else result=FAIL; fi
    printf '%s\t%s\t%s\t%s\n' "$sym" "$crc" "$expected" "$result" >>"$WORK/kernel-crc.tsv"
  fi
done <"$WORK/und.nm"
[ "$kernel_match" -eq "$kernel_total" ] && pass "all actual kernel imports CRC exact ($kernel_match/$kernel_total)" || { bad "all actual kernel imports CRC exact ($kernel_match/$kernel_total)"; cat "$WORK/kernel-crc.tsv"; }
[ "$telemetry_match" -eq "$telemetry_total" ] && pass "all actual telemetry imports CRC exact ($telemetry_match/$telemetry_total)" || { bad "all actual telemetry imports CRC exact ($telemetry_match/$telemetry_total)"; cat "$WORK/telemetry-crc.tsv"; }
layout=$(mod_crc module_layout); [ "$layout" = 0x3a3eb6e9 ] && pass 'module_layout exact = 0x3a3eb6e9' || bad "module_layout exact = 0x3a3eb6e9 (got $layout)"
readelf -p .modinfo "$KO" | grep -q 'vermagic=5.4.238 SMP mod_unload modversions aarch64' && pass 'vermagic exact' || bad 'vermagic exact'

probe() { awk -v k="$1" '$1 == k {print $2; exit}' "$2"; }
[ "$(probe sz_net_device "$ROOT/static/netdev-layout-vendor.tsv")" = 2241 ] && pass 'net_device sizeof target 0x8c0 (probe raw 2241)' || bad 'net_device sizeof target 0x8c0'
[ "$(probe off_netdev_priv "$ROOT/static/netdev-layout-vendor.tsv")" = 2241 ] && pass 'netdev_priv target 0x8c0 (probe raw 2241)' || bad 'netdev_priv target 0x8c0'
[ "$(probe off_dev_addr "$ROOT/static/netdev-layout-vendor.tsv")" = 793 ] && pass 'dev_addr target 0x318 (probe raw 793)' || bad 'dev_addr target 0x318'
[ "$(probe off_dev "$ROOT/static/netdev-layout-vendor.tsv")" = 1297 ] && pass 'struct device base target 0x510 (probe raw 1297)' || bad 'struct device base target 0x510'

aarch64-linux-gnu-objdump -dr "$KO" >"$WORK/objdump-dr"
grep -A45 '<gether_register_netdev>:' "$WORK/objdump-dr" >"$ROOT/static/rebuilt-gether-register-netdev.disasm"
grep -q 'ldr.*\[x0, #744\]' "$ROOT/static/rebuilt-gether-register-netdev.disasm" && bad 'gether_register_netdev dev_addr uses vendor offset 0x318' || pass 'gether_register_netdev dev_addr uses vendor offset 0x318'
grep -q 'ldr.*\[x0, #1296\]' "$ROOT/static/rebuilt-gether-register-netdev.disasm" && pass 'gether_register_netdev uses struct device base 0x510' || bad 'gether_register_netdev uses struct device base 0x510'

grep -q 'f[[:space:]]*+0xa0\|offsetof.*f).*0xa0' "$ROOT/source/u_ncm.h" && pass 'usb_function_instance f +0xa0 source gate' || bad 'usb_function_instance f +0xa0 source gate'
grep -q 'set_inst_name.*0xa8' "$ROOT/source/u_ncm.h" && pass 'usb_function_instance set_inst_name +0xa8 source gate' || bad 'usb_function_instance set_inst_name +0xa8 source gate'
grep -q 'free_func_inst.*0xb0' "$ROOT/source/u_ncm.h" && pass 'usb_function_instance free_func_inst +0xb0 source gate' || bad 'usb_function_instance free_func_inst +0xb0 source gate'
printf 'RESULT=%s\n' "$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
