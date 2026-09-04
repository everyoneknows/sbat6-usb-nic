# T6A CDC-NCM Windows re-enumeration confirmation — 2026-09-04 21:28 JST

管理経路は `agent-101-vm -> raspi2 -> LAN/SSH -> root@192.168.3.2` のみ。
ADB、runtime2、USB role操作、candidate差替えは使用していない。

旦那さまのWindows Pavilion接続後、T6A上で以下を読み取り確認した。

- USB mode: `3` (DEVICE)
- ConfigFS: `f5 -> /config/usb_gadget/g1/functions/ncm.gs8`
- UDC: `11201000.usb`
- UDC state: `configured`
- USB speed: `high-speed`
- gadget VID/PID: `0x2c7c:0x7006`
- gadget product: `RG620T-SBK`
- `ncm0`: `UP`, `192.168.77.1/24`, carrier `1`
- `rx_errors=0`, `rx_dropped=0`, `tx_errors=0`, `tx_dropped=0`
- Windows peer `192.168.77.2`への ping: 3/3、損失0%、平均3.320ms

`configured`、VID/PID、NCM carrier、IP疎通が揃ったため、Windows側の
`2c7c:7006 / UsbNcm Host Device` 再列挙およびNCMリンク成立を確認済みと判定する。
追加のIP設定、速度試験、設定変更は行っていない。
