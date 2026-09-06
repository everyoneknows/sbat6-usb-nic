# T6A CDC-NCM bMaxBurst=15 P1 follow-up and next hypothesis — 2026-09-04

## 判定

主評価の P1（T6A → raspi4）は `1.32 Gbit/s`, Retr `0` で、baseline
`1.33–1.34 Gbit/s`を上回らなかった。改善条件は成立していないため、同一条件の
再現試験およびP4は実施しない。

既存のbMaxBurst候補はhost-visible descriptorではIN/OUTとも `15` だが、速度改善は
確認できなかった。現時点では「bMaxBurst=15が有効な速度改善要因」という仮説を棄却し、
実転送の集約・要求供給を次の対象とする。

## 現在状態の読み取り確認

変更操作は行わず、専用鍵で `kuroko-lab@192.0.2.10` に接続して採取した。

- raspi4 `usb0`: `UP`, `LOWER_UP`, `192.168.250.2/30`, `carrier=1`
- raspi4 kernel: `6.18.34+rpt-rpi-v8`, aarch64
- USB device: `2c7c:7006`, SuperSpeed 5Gbps
- CDC-NCM bulk IN EP8 / OUT EP5: `wMaxPacketSize=1024`, `bMaxBurst=15`
- `dwNtbInMaxSize=16384`, `dwNtbOutMaxSize=16384`
- `rx_max=16384`, `tx_max=16384`, `min_tx_pkt=13312`
- `wNtbOutMaxDatagrams=6`, `tx_timer_usecs=400`
- Linux netdev queue: `rx-0` / `tx-0`各1本
- raspi4 `usb0` readout時点の累積統計: RX errors 1, TX errors 1, TX collisions 7
- ping raspi4 → T6A (`192.168.250.1`): 3/3成功、平均3.504 ms
- raspi4上にiperf3 serverは稼働していない

## 根拠の分類

### FACT

- P1通常方向は `1.32 Gbit/s`, Retr `0`。[P1記録](t6a-ncm-bmaxburst15-p1-20260904.md)
- raspi4でbulk IN/OUTの `bMaxBurst=15` を読み取った。[主評価記録](t6a-ncm-bmaxburst15-iperf-20260904-1152.md)
- raspi4のNCM上限と受信側設定は16KiBで一致している。これは今回の読み取り結果である。
- reverse方向のtimer sweepは400/100usで1.01 Gbit/s、0usで755 Mbit/s、復元後1.01 Gbit/s。
  [timer sweep記録](t6a-cdc-ncm-timer-sweep-20260904.md)

### INFERENCE

- P1主方向ではraspi4のTX timerはデータ送信経路ではないため、timer sweepの結果をP1改善の
  根拠にはできない。
- gadgetのIN側NTB上限とhost `rx_max` がともに16KiBであるため、片側だけの静的拡大は
  整合性を欠く。

### HYPOTHESIS

- 主方向の共通上限は、16KiB NTB内の実転送長、NDP datagram数、またはhost受信URBの
  in-flight供給／完了待ちで生じている可能性がある。
- bMaxBurstの変更はdescriptorで確認できても、現構成のボトルネックがUSB burstより上位の
  NCM/MTU3 request供給であれば、速度が変わらないことを説明できる。

### UNKNOWN

- P1実行中のbulk transfer長、short/ZLP、NDP datagram数、in-flight URB数、USB IRQ/softirqの
  実時間分布。
- raspi4 `usb0` の累積error/collisionがP1以前から存在したか、P1中に増加したか。

## 次の安全な実験

raspi4側のusbmonまたはUSB traceを読み取り専用で開始し、T6A側から同一条件のP1を一回
だけ実行する。transfer長、完了間隔、同時URB数、NCM NTB/NDPの分布を保存し、異常がなければ
P1の再測定値と突き合わせる。sysfs値、module、descriptor、IP、role、再bind、再起動は変更しない。

ただし現時点ではT6A (`192.168.3.2`) のSSH認証が通らず、P1を開始する操作ができない。
raspi4への疎通・IP・descriptor確認は完了しているため、次回T6A操作経路が復旧したらこの
trace採取を先に行う。認証回復まで、timerやNTB値の変更は行わない。

## 結論

`bMaxBurst=15` 条件の主方向P1は baseline 改善なし。通信異常は観測されていないが、
次の実験へ進むためのT6A操作経路が不足している。現状態は維持し、受信NTB/request供給の
実測を次工程とする。

> Privacy note (2026-09-06): personal paths, management addresses and device MACs in this document are redacted or replaced with examples; they are not original measured identifiers.
