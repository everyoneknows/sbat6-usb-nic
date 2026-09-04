# 次仮説：host CDC-NCM timer／NTB集約（2026-09-04）

## 選定

`bMaxBurst` は host-visible descriptor に反映されなかったため、次は
**raspi4 の host `cdc_ncm` が16KiB NTBをどのタイミングでflushしているか**を
検証する。T6Aのmodule、再起動、role、GPIO、VBUS、flash、DTは対象外である。

### 根拠の分離

- **FACT**: T6A実測は P1=1.34 / P4=1.38 Gbit/s、Retr=0。`lsusb`のNCM bulk
  IN/OUTは `bMaxBurst=0`。旧offset `0x10c52`は対象外で、正しい候補は未適用。
- **FACT**: Linux 5.4.238 `cdc_ncm` は `tx_timer_usecs` をsysfsで変更でき、
  0 または最小値以上を受け付ける。`tx_max/rx_max` はdeviceのNTB上限で検査される。
- **INFERENCE**: gadget側広告値が16KiBのままなら、hostだけで32/64KiBへ拡大する
  のは不適切。timerは変更範囲が狭く、可逆で、flush待ちの寄与を直接切り分けられる。
- **HYPOTHESIS**: 400µsのhost flushがNTB充填またはUSB request供給を阻害している。
  100µsまたは0µsで実効速度・transfer長・再送が改善すれば、集約タイミングが律速。
- **UNKNOWN**: raspi4の実際のsysfs値、kernelが許す最小値、bulk transfer長、
  in-flight request数、T6A vendor wrapの処理時間。総CPU使用率だけでは判定しない。

## 実装直前セット

準備済み: [prepare_raspi4_cdc_ncm_timer_sweep.py](../../tools/prepare_raspi4_cdc_ncm_timer_sweep.py)

raspi4上で `usb0` の存在と `cdc_ncm/tx_timer_usecs` を読み取り、JSON snapshotを保存する。
デフォルト実行は読み取り専用で、`--apply`を明示したときだけ1値を書き込む。
snapshotの `before` を使う `--restore` で正確に切り戻せる。永続設定は変更しない。

## 測定方向の確定（旦那さま確認済み）

主評価は **raspi4 → T6A** とする。raspi4を `iperf3` server
（`192.168.250.2`）のまま維持し、T6Aから次を実行する。

```text
iperf3 -c 192.168.250.2 -R
```

`-R` によりデータ送信元はraspi4となるため、raspi4 host-side
`cdc_ncm/tx_timer_usecs` のTX aggregation/flushへの影響を主経路で評価できる。
T6Aはiperf serverにしない。各条件は同一方向・同一iperf条件で実施し、
bitrate、Retr、raspi4/T6AのCPU、必要時はUSB transfer長を保存する。

実験順は `baseline → 100µs → 0µs → snapshot値復元`。baselineはraspi4の
実測保存値を使い、400µsとは仮定しない。従来の **T6A → raspi4 P1** は
controlとして最初に1回だけ保持し、timer sweepの主評価には混ぜない。
各段階の前後に値を再読し、`lsusb -v`、`ip -s link`、`ethtool -S`、
`usbmon`、dmesgのreset/stall/timeout/retryを保存する。

## 期待値と停止条件

期待改善は小〜中（目安0〜20%）で、3Gbps到達は仮定しない。成功は同一条件で
中央値がベースラインを明確に上回り、packet loss/retry/resetが増えないこと。
性能低下、packet loss、USB reset/disconnect、stall、timeout、kernel warning、
値の書戻し失敗があれば即時baselineへrestoreして停止する。

## 次の実装判断

timer差が無ければ、次は静的NTB拡大ではなく、usbmon/traceで request長・in-flight数・
NDP datagram数を測定し、MTU3 QMU/request queueまたは `ncm_wrap_ntb_mtk` の
memcpy/allocを優先する。`bMaxBurst=15` candidateは別実験として保留し、T6Aへ追加適用しない。
