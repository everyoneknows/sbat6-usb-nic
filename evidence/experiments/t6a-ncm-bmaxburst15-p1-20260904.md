# T6A CDC-NCM bMaxBurst=15 P1 再測定 — 2026-09-04

## 経路

T6A操作は既知のLAN/SSH経路のみを使用した。

`agent-101-vm -> raspi2 -> root@T6A-MGMT-IP`

ADB、USB serial、Zen3経路は使用していない。

## 測定前状態

- T6A `ncm0`: `UP`, `LOWER_UP`, `192.168.250.1/30`, carrier=1
- raspi4 `usb0`: `UP`, `LOWER_UP`, `192.168.250.2/30`, carrier=1
- raspi4 `cdc_ncm`: `tx_timer_usecs=400`, `tx_max=16384`, `rx_max=16384`, `min_tx_pkt=13312`
- T6A対象USB `2c7c:7006` はSuperSpeed (5Gbps)
- 対象CDC-NCM bulk IN/OUTの `bMaxBurst=15` を `lsusb -s 002:009 -v` で確認
- T6A側のmodule、descriptor、再bind、再起動、IP設定変更は行っていない

## P1

従来と同一条件:

```text
iperf3 -c 192.168.250.2 -t 10
```

- 方向: T6A → raspi4
- 結果: **1.32 Gbit/s**（10.00秒）
- 転送量: 1.53 GBytes
- Retr: 0
- 終了コード: 0
- 1秒間隔: 1.24, 1.29, 1.33, 1.33, 1.35, 1.33, 1.32, 1.34, 1.30, 1.32 Gbit/s
- 比較基準: 1.33〜1.34 Gbit/s
- 判定: 基準を上回る改善なし。再現試験およびP4は実施しない

## 検証

- ping `192.168.250.2`: 3/3成功、平均3.729 ms
- 測定後もT6A `ncm0` は `UP/LOWER_UP`, `192.168.250.1/30`
- 測定後もraspi4 `usb0` はcarrier=1, `192.168.250.2/30`
- 測定後も対象bulk IN/OUTは `bMaxBurst=15`
- 一時iperf3 serverは `--one-off` で起動し、測定後に停止済み
- 測定中のUSB reset/disconnect、timeout、stallは確認されず

## 結論

bMaxBurst=15および既存のNCM条件を壊さずP1を再測定したが、1.32 Gbit/sで従来基準に対する改善は確認できなかった。P4や再現試験へ進む条件は成立しなかった。
