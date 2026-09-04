# T6A CDC-NCM bMaxBurst=15 主方向 P1 follow-up — 2026-09-04 12:03 JST

## 目的

`bMaxBurst=15`、SuperSpeed、T6A `ncm0` / raspi4 `usb0`、既存IP設定を維持し、
主評価方向 **T6A → raspi4** を再測定する。`-R` は使用しない。

## 条件確認

- T6A: `ncm0 UP/LOWER_UP`, `192.168.250.1/30`, carrier=1
- raspi4: `usb0 UP`, `192.168.250.2/30`, carrier=1
- T6A: Linux 5.4.238 aarch64, iperf3 3.10.1
- raspi4 host cdc_ncm: `tx_timer_usecs=400`, `tx_max=16384`, `rx_max=16384`, `min_tx_pkt=13312`
- 既知の host-visible CDC-NCM bulk IN/OUT: `bMaxBurst=15`
- MTU: 両端1500
- module、descriptor、再bind、再起動、IP設定、role、物理ケーブルは変更なし

## P1

T6A側で実行:

```text
iperf3 -c 192.168.250.2 -t 10
```

- 方向: T6A → raspi4
- 接続: `192.168.250.1:44278 -> 192.168.250.2:5201`
- 結果: **1.33 Gbit/s**、10.01秒、1.55 GBytes
- Retr: **0**
- 終了コード: 0
- 1秒間隔: 1.20, 1.36, 1.31, 1.33, 1.34, 1.35, 1.35, 1.37, 1.35, 1.32 Gbit/s

## 判定

従来の同条件P1 `1.32 Gbit/s` より0.01 Gbit/s高いが、比較baseline
`1.33–1.34 Gbit/s` の下端に一致する範囲であり、再現性・有意な改善とは判定しない。
従ってP4へ進む改善条件は成立しない。

`bMaxBurst=15` が単独で約1.3 Gbit/s天井を破る証拠は今回も得られない。
16 KiB NTB、NDP集約、request/in-flight供給、`ncm_wrap_ntb_mtk`、MTU3 QMU/GPD
 batching、single queue/lock、DMA/memcpyの仮説は維持する。

## 測定後の検証

- T6A `ncm0`: RX errors 0、TX errors 0、carrier errors 0、状態維持
- raspi4 `usb0`: `UP/LOWER_UP`、carrier=1、状態維持
- raspi4累積値は測定前の RX `1714719506` bytes / `1326464` packets から
  RX `3435081821` bytes / `2479190` packets へ増加。errorsは1のまま。
- raspi4の一時iperf3 serverはone-off測定後に終了確認済み
- raspi4でusbmon live fileは権限不足により列挙できず、bulk transfer長・NDP数・
  in-flight URB数の直接traceは未取得。tracefs/debugfsの変更は行っていない。
- USB reset/disconnect/timeout/stallは測定出力および確認範囲で観測なし

## 次の判断

P1追加で改善は確認できなかったため、P4は行わない。次は条件を変えずに取得できる
観測として、raspi4側のusbmon/trace権限を整えた後、同一方向P1とbulk transfer分布を
対応付けるのが最優先である。権限拡張やroot操作は今回行っていない。

reverse方向の既取得 `1.01 Gbit/s / Retr 115` は別方向controlとして保持する。
