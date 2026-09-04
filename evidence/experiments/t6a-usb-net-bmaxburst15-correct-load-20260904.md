# T6A usb_net bMaxBurst=15 correct candidate load — 2026-09-04

## Scope

旦那さまのUSB A-Aケーブル抜去後、T6Aの一時`usb_net` moduleを、NCM bulk
companionの正しい候補へ可逆的に差し替えた。永続module、flash、mode、GPIO、
VBUS、DT、IP設定は変更していない。

## Precondition

- Target identified as T6A / OpenWrt 21.02.7 / Linux 5.4.238.
- `MODE=3`, GPIO322=`0`, xHCI platform device absent.
- UDC `11201000.usb`: `not attached`, current speed `UNKNOWN`.
- `ncm0` was present and DOWN.
- Vendor `/lib/modules/5.4.238/usb_net.ko` SHA256:
  `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`.
- Correct candidate SHA256:
  `155f36377a9d3fb51b15f9271c55881f332ec94d518fa6fbf1ca26917705e232`.

## Action

1. Removed the existing NCM ConfigFS function/link and unbound UDC with a
   newline-terminated write.
2. The first normal `rmmod` was refused while `usb_net` still had use count 2.
   No forced unload was attempted.
3. Removed the now-unbound residual `ncm.gs8` function directory; module use
   count reached 0.
4. Saved the vendor module under
   `/tmp/butlerx-usb_net-bmaxburst15-before-20260904c/usb_net.original.ko`.
5. Loaded `/tmp/butlerx-t6a-usb_net-bmaxburst15-correct-20260904.ko`.
6. Recreated `ncm.gs8`, restored `qmult=30`, linked it as config `f5`, and
   rebound UDC `11201000.usb`.

## Verification

- Candidate readback SHA256 matched the prepared candidate exactly.
- `usb_net` loaded with use count 2.
- `ncm0` was recreated, DOWN while disconnected, MTU 1500.
- UDC remained `not attached`; speed remained `UNKNOWN`.
- No new USB/NCM oops, stall, timeout, reset, or call trace was observed.
- Host-visible descriptor (`bMaxBurst` on bulk IN/OUT) and throughput are
  intentionally pending cable reconnection.

## Verdict

`PASS — correct candidate loaded and disconnected gadget restored.`
