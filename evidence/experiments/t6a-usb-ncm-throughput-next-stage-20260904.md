# T6A CDC-NCM 実効速度 次工程 — 2026-09-04

## 判定

`bMaxBurst=15` の正しい静的候補は `usb_net.ko` の file offset
`0x10fd2`（`.data+0xa48`、共有 SS bulk companion）である。しかし、今回の
実機試験は `lsusb` が bulk IN/OUT とも `bMaxBurst=0` のままで、速度は
P1=1.34 / P4=1.38 Gbit/s だった。よって「15にしても効かなかった」ではなく、
「適用候補が host-visible descriptor に到達しなかった」と分類する。

今回の成果物では新しい T6A 操作、module交換、再起動、runtime変更を行わない。

## A. 律速候補ランキング

評価は **改善幅 / 難易度 / 実機リスク / 切戻し / 1.38Gbps整合性** の順に、
`大・中・小`で示す。FACT等は混ぜない。

1. **host/gadget NCM aggregation と NTB 16KiB の組合せ** — 改善幅: 中〜大 / 難易度: 中 / リスク: 中 / 切戻し: 容易 / 整合: 高。
   - FACT: gadget `dwNtbInMaxSize`/`dwNtbOutMaxSize` は 0x4000、host側は
     `tx_max`/`rx_max`/`min_tx_pkt` をこの値から決める。`wNtbOutMaxDatagrams=6`
     は実機取得値として扱うが、保存済み一次ログでの再確認が必要。
   - INFERENCE: 16KiB単位は3Gbps級を狙うには転送・完了回数が多い。
   - HYPOTHESIS: NTBを32/64KiBへ揃え、datagram上限も整合させるとCPU/request
     overheadが下がる。
   - UNKNOWN: deviceが大きいNTBを安全に受けるか、hostが実際に何KiBを送受するか。

2. **gadget `ncm_wrap_ntb_mtk` の payload memcpy + alloc/NDP/CRC** — 改善幅: 中〜大 / 難易度: 大 / リスク: 中〜高 / 切戻し: 中 / 整合: 高。
   - FACT: binaryに16KiB作業buffer、`memcpy`、NDP構築、CRC、timer flush相当がある。
   - INFERENCE: 総CPU使用率が低くても、single TX pathの局所CPU/cache帯域を消費し得る。
   - HYPOTHESIS: zero-copyまたは再利用bufferで1.38Gbpsの共通上限が上がる。
   - UNKNOWN: vendor hookの実測時間と、CRCが有効か。

3. **MTU3 endpoint request queue depth / request size / QMU-GPD batching** — 改善幅: 中〜大 / 難易度: 大 / リスク: 高 / 切戻し: 中 / 整合: 高。
   - FACT: upstream MTU3は request length を GPD上限まで検査し、`mep->req_list`
     へ追加して `mtu3_insert_gpd()`、`mtu3_qmu_resume()`を行う。`mtu->lock`を
     IRQ保存付きで共有する。
   - INFERENCE: queueが1本または浅ければ、CPU総量ではなく待ち合わせで律速する。
   - HYPOTHESIS: requestを複数先行投入し、GPD/QMU完了をbatch化すると改善する。
   - UNKNOWN: T6A vendor QMUの実際の深さ、同時in-flight本数、DMA待ち時間。

4. **single `tx-0` / `rx-0` と endpoint lock/serialization** — 改善幅: 中 / 難易度: 大 / リスク: 高 / 切戻し: 中 / 整合: 高。
   - FACT: 保存済み観測は `tx-0` / `rx-0`。MTU3コードは単一 controller lock と
     endpoint request listを使う。
   - INFERENCE: iperf stream数を増やしてもUSB経路が増えない。
   - HYPOTHESIS: queue分割またはlock保持時間短縮でP4頭打ちが緩和する。
   - UNKNOWN: `tx-0`が論理名だけか、真の単一QMU ringか。

5. **USB request size / request count と DMA descriptor batching** — 改善幅: 中 / 難易度: 大 / リスク: 高 / 切戻し: 中 / 整合: 中〜高。
   - FACT: request長、in-flight数、DMA descriptor待ちは未観測。
   - INFERENCE: burst変更が効かなかった今回の結果は、下位request供給が支配する説明と整合。
   - HYPOTHESIS:大きいrequestと複数GPDがUSB bus idleを減らす。
   - UNKNOWN: firmware/QMU制限。

6. **host `cdc_ncm` の `tx_max` / `rx_max` / `min_tx_pkt` / `tx_timer_usecs=400`** — 改善幅: 小〜中 / 難易度: 小 / リスク: 低 / 切戻し: 非常に容易 / 整合: 中〜高。
   - FACT: upstream cdc_ncmには各sysfs knobがあり、`rx_urb_size`とusbnet queue長へ波及する。
   - INFERENCE: host側だけで変更でき、最小変更で情報量が大きい。
   - HYPOTHESIS: timerを短く/無効、`tx_max`をdevice上限内で変更することで、flush待ちかNTB不足かを識別できる。
   - UNKNOWN: raspi4 kernelがsysfs knobを有効化しているか、現在値。

7. **MTU / jumbo frame** — 改善幅: 中 / 難易度: 中 / リスク: 中 / 切戻し: 容易 / 整合: 中。
   - FACT: NCM datagramは Ethernet frame 単位で、現在のMTU値は未取得。
   - HYPOTHESIS: jumboでper-packet NCM/stack overheadを減らせる。
   - UNKNOWN: T6A、raspi4、forwarder経路の全区間が対応するか。

8. **IRQ / softirq affinity、cache/memcpy帯域** — 改善幅: 小〜中 / 難易度: 中 / リスク: 低〜中 / 切戻し: 容易 / 整合: 中。
   - FACT: 総CPU使用率だけでは局所飽和を否定できない。IRQ/softirqとcache missは未観測。
   - HYPOTHESIS: USB IRQとNCM softirqの同一CPU集中が待ち時間を作る。
   - UNKNOWN: IRQ番号、CPU配置、perf/tracepoint利用可否。

9. **timer flush 単独** — 改善幅: 小 / 難易度: 小 / リスク: 低 / 切戻し: 容易 / 整合: 低〜中。
   - FACT: gadgetのNTB構築にtimer flushがあり、hostにも `tx_timer_usecs` がある。
   - HYPOTHESIS: 400usがbulk連続送信を不必要に分割する。
   - UNKNOWN: high-load時にtimer経路が実際の割合を占めるか。

10. **iperf3 / T6A forwarderそのもの** — 改善幅: 不明 / 難易度: 小 / リスク: 低 / 切戻し: 容易 / 整合: 中。
    - FACT: P1/P4の測定のみで、raw bulk、別host、単純forwarderとの差は未測定。
    - HYPOTHESIS: iperf3/TCPまたはT6A forwardingがendpointではなく上限を作る。
    - UNKNOWN: UDP/raw bulk/forwarder対照の結果。

11. **`wNtbOutMaxDatagrams=6` 単独** — 改善幅: 小〜中 / 難易度: 中 / リスク: 中 / 切戻し: 容易 / 整合: 中。
    - FACT: 6という値は候補として提示されたが、現在のraspi4 sysfs一次値は未収集。
    - INFERENCE: 16KiBなら6個制限はフルMTU時に必ずしも支配的でない。
    - HYPOTHESIS: 小パケット負荷ではNDP/transfer回数が増える。
    - UNKNOWN: 実際のdatagram分布。

## B. 次に行う実験（変更の小さい順）

1. raspi4の読み取り専用採取: `lsusb -v`、`ip -s link`、cdc_ncm sysfs全値、
   `ethtool -k/-S`、`/proc/interrupts`、`/proc/softirqs`、kernel log。T6Aは触らない。
2. 同じ接続で、host側 `tx_max`/`rx_max`/`min_tx_pkt`/timerを一つずつ、変更前値へ戻せる範囲でA/B。これはT6A変更ではないが、GO時に実施する。
3. payload/NTB観測: usbmon/traceでbulk transfer長、short/ZLP、in-flight近似、NTB datagram数を採取。
4. P1/P4/P10に加え、UDP、CPU pinning、MTU対照、T6A単純forwarder対照。
5. 最後に予備機で `0x10fd2` candidateのdescriptor-only試験。T6A本番はGO後のみ。

## C. 実装候補

- **C1 host knob sweep**: raspi4 `cdc_ncm` sysfsの既存値を保存し、`tx_timer_usecs`、
  `min_tx_pkt`、device上限内の`tx_max/rx_max`を一変数ずつ変更。rollbackは保存値write。
- **C2 source rebuild**: vendor `f_ncm.c` の `ss_ncm_bulk_comp_desc.bMaxBurst=15`
  を明示し、`usb_net.ko`を再生成。binary固定offsetは配布patchにしない。
- **C3 NTB拡大**: gadget `NTB_*_SIZE`、NCM parameter、host negotiationを一組として変更。
  片側だけ変更しない。rollbackは旧moduleと旧host値。
- **C4 request/QMU**: MTU3のqueue depth/GPD batchingをtraceで根拠化してから変更。
  DT変更、flash、bootloaderは不要で、現段階では未実装。
- **C5 zero-copy/buffer reuse**: `ncm_wrap_ntb_mtk`のalloc/memcpy境界をsourceまたは
  完全な関数復元で確認後に着手。CRC on/offも別因子として記録。

## D. 実装直前セット

準備済みスクリプト: `tools/prepare_t6a_bmaxburst15.py`。

```text
入力: analysis/t6a-usb_net/t6a-usb_net.original.ko
出力: analysis/t6a-usb_net/t6a-usb_net.bmaxburst15-correct-candidate.ko
対象: file 0x10fd2, .data+0xa48, 00 -> 0f
guard: ELF、descriptor context、期待byte、差分1 byteを検査
実機操作: なし
```

既知SHA256は原本 `271919fa9a37b00d03f73c1d390bf7360384562286c88b9619714877718e748f`。
正しいcandidate SHA256は生成時にスクリプトが表示する（旧 `0x10c52` candidateの
SHA256 `c70c...` は使用禁止）。

GO後の順序は、(a)安全条件 MODE=3 / xHCI absent / GPIO322 LOW / VBUS 0Vを採取、
(b) module SHA/vermagic/depends保存、(c) originalを退避、(d) patched load、
(e)通信なしでhost descriptor IN/OUT=15確認、(f)異常がなければP1/P4/P10、
(g)失敗時は通信停止・original復帰・descriptor/log再確認、である。

STOPは、module拒否、oops/warning、USB reset/disconnect、stall、request timeout、
packet loss/再送急増、性能低下、温度・電力異常。flash、bootloader、DT、GPIO307/323、
RT9467、runtime2、旧usb_role helper、直接role APIは使用しない。

## 参照した実装

- `work/src/linux-5.4.238/drivers/usb/gadget/function/f_ncm.c`: 16KiB、bulk companion、
  wrap/memcpy/CRC/timer、descriptor assignment。
- `work/src/linux-5.4.238/drivers/usb/mtu3/mtu3_gadget.c`: companion burst、request length、
  controller lock、endpoint request list/GPD/QMU。
- `work/build/linux-5.4.238-air6-upstream/drivers/net/usb/cdc_ncm.c`: host `tx_max`/`rx_max`,
  `min_tx_pkt`, timer、rx URB/queue更新。
- 最新 upstreamの `f_ncm.c` は bulk companion に `.bMaxBurst = 15` を明示し、`cdc_ncm.c`
  はこれらのsysfs調整経路を持つ。一次参照: Linux upstreamの
  [f_ncm.c](https://github.com/torvalds/linux/blob/master/drivers/usb/gadget/function/f_ncm.c)、
  [cdc_ncm.c](https://github.com/torvalds/linux/blob/master/drivers/net/usb/cdc_ncm.c)、
  [mtu3_gadget.c](https://github.com/torvalds/linux/blob/master/drivers/usb/mtu3/mtu3_gadget.c)。
