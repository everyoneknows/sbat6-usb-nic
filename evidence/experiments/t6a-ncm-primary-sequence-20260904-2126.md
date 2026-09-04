# T6A CDC-NCM primary sequence continuation — 2026-09-04 21:26 JST

管理経路は `agent-101-vm -> raspi2 -> LAN/SSH -> root@192.168.3.2` のみ。
ADB、runtime2、role操作、MODE書込み、candidate差替えは使用していない。

## Preconditions and action

- `MODE=3`、xHCI platform device absent を確認。
- `f5` の実体が `functions/ncm.gs8` であることを `readlink -f` で確認。
- 一次資料のConfigFS再bind手順を実行:
  - `echo > /config/usb_gadget/g1/UDC`
  - `echo 11201000.usb > /config/usb_gadget/g1/UDC`

## Verification

- `f5 -> ../../../../usb_gadget/g1/functions/ncm.gs8`
- UDC: `11201000.usb`
- UDC state: `not attached`
- `ncm0`: `DOWN`, `NO-CARRIER`
- carrier: `0`
- SSH管理LANは維持。

## Next gate

T6Aはケーブル未接続のDEVICE待機状態。次は旦那さまがWindows Pavilion側を
接続した後、UDC `configured`、`ncm0` carrier、Windowsの
`2c7c:7006 / UsbNcm Host Device` 再列挙を確認する。IP設定や通信試験は
列挙確認まで行わない。
