# Vendor binary evidence

`usb_net.ko` is the saved T6A vendor provider, SHA256
`271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.

The vendor ELF is relocatable and not stripped. It contains local NCM/ECM/RNDIS
function and `gether` implementations, vendor-only symbols/CRCs, and the
embedded source path recorded in the candidate README. No corresponding
vendor `f_ncm.c`, `u_ether.c`, configfs headers, Makefile or Kconfig was found
on the build host. Consequently a line-by-line vendor diff is unavailable and
is listed as a hard audit limitation.
