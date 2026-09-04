# T6A USB NCM 既存環境最適化ルート 初期監査 — 2026-09-04

## 範囲と安全状態

保存済みの実機観測・静的解析・可逆A/B結果を統合した初期監査。
この監査ではT6Aへの新たな module load、UDC unbind/rebind、USB role変更、
ConfigFS変更、再起動、物理ケーブル操作は行っていない。

現在の基準状態は、Linux 5.4.238/aarch64、UDC `11201000.usb`、
`ncm0`、SuperSpeed、MTU 1500、qmult 30、NCM `tx_max=rx_max=16384`。
trace eventは無効化状態で、これは既存の低速化原因を除去するために行われた
可逆操作の最終状態である。

## 現在の判断

1.34Gbpsの主制限は、host request不足や単純なqmult不足ではなく、vendor
NCMの16KiB単位のblock packing、payload copy/alloc、単一のTX/RX処理経路、
およびMTU3 QMUへの投入・完了処理の組合せが最有力である。

`qmult=30`からupstreamのように各方向60 requestと推定することはできない。
vendor `gether_connect` はRX側 `w26` とTX側 `w27`を別計算する。
保存済みのlive module/`hw_nat.ko`解析では `w26=80`、PPE hook戻り値4、
writerの `+1` と clamp により `dev[454]` の候補は5、従ってTX allocation
は16回という構造まで解決した。ただし、writerが現在のprivate objectへ
実行済みであることと、allocation成功数は未証明である。

MTU3のbulk endpointには64-entry QMU/GPD ringと3KiB FIFOが見えるが、これは
gadget `usb_request` poolの数ではない。host usbmonでは16,384-byte submitが
確認され、完了間隔中央値38.86us、p95 424.86us（trace無効のcapture）で、
host側request starvationは主因としては下がった。

## 一変数試験の統合表

| 項目 | 初期値 | 試験値 | throughput / CPU等 | 判定 |
|---|---:|---:|---|---|
| baseline P1（再現3回） | trace off, 16KiB | 同一条件 | T6A→raspi4: 1.34 / 1.30 / 1.31Gbps、Retr 0 | 安定基準。CPUはT6A 1.61GHz、schedutil、全体load約9.7（4 core） |
| host `rx_max` | 16384 | 8192 | receiver 6.18Mbps、sender 7.74Mbps、Retr 867、RX error 1→251 | 明確に悪化。不採用。16384へ復元済み |
| T6A USB IRQ 305 affinity | CPU0 (`0-3`, effective 0) | CPU1 | 1.33Gbps、Retr 0 | 単独効果なし。`0-3`へ復元済み |
| `tx_buff_num` | 0 | 32 / 64 / 80 | T6A→host: 1.31 / 1.31 / 1.30Gbps。単調改善なし | TX request override単独は不採用。0へ復元済み |
| trace event master | event off | event on時の既知状態 | 482Mbpsまで低下。offで1.33Gbpsへ回復 | trace overheadが低速状態の原因。event offを維持 |
| SS bulk `bMaxBurst` | host-visible 15 | 15候補/確認 | high-rate captureで15、速度1.30–1.35Gbps | 既に正しい。15単独を未適用/不適用と誤分類しない |

過去のWindows測定（Windows→T6A約1.02Gbps、T6A→Windows約1.34Gbps）および
Raspberry Pi 4 hostでも同傾向という記録とも整合する。

## mainlineとの差分から得た候補

現行Linux mainlineの `u_ether` はHigh/SuperSpeedで `qmult * 2` をqueue長に
使い、TX/RXへ同じ数をpreallocateする。一方、保存されたT6A vendor ELFは
別の `w26/w27`計算、PPE hook、vendor NCM wrapを持つため、単純なmainline
置換やqmult表示値からのrequest数推定は不適切である。

現行mainlineのhost `cdc_ncm` は、deviceのNTB parameterを読み、
`rx_max`/`tx_max`をdevice上限へclampし、NTB32を選択可能な場合がある。
ただしT6Aのadvertised `dwNtbInMaxSize`/`dwNtbOutMaxSize`は16KiBであり、
host側だけを拡大する変更は互換性を満たさない。NTB拡大はgadget descriptor、
実装、host negotiationを一組で変更する必要がある。

## 未解決の測定点

- 現在のT6A private object上の`dev[454]`実byte。
- vendor TX/RX request listの実allocation成功数とsteady-state in-flight数。
- NCM NTBの実datagram数を含む、vendor NCMHの完全なblock packing統計。
- MTU3 QMU ringのstarvation/idle gapと、`usb_request` completionの対応関係。
- DMA mapping、copy時間、NCM flush timerの実行比率。
- CPU per-coreのIRQ/softirq時間とthermal throttlingの有無（保存済み基準では4 core 1.61GHz）。

## 次の優先順位

既存環境の可逆・低リスク範囲では、`rx_max`、IRQ affinity、`tx_buff_num`、
trace overheadは既に判定済みである。残る有力候補は、(1) vendor NCMの
16KiB packing/flush、(2) copy/alloc経路、(3) MTU3 request/QMU completionの
直列化である。これらはruntime knobだけでは解決しにくく、標準kernelのまま
2Gbpsを確定できる根拠は現時点でない。

標準kernelを変更せずに追加できるのは、既存debugfs・sysfs・host usbmonの
読み取り採取と、既存host側NCM knobの保存付き一因子試験までである。NTB
サイズ、NDP形式、vendor module、MTU3 driverを変更する試験は、別buildまたは
予備機での検証を先に行うべきであり、本番T6Aへは進めない。

## 一次資料

- Linux mainline `f_ncm.c`: https://github.com/torvalds/linux/blob/master/drivers/usb/gadget/function/f_ncm.c
- Linux mainline `u_ether.c`: https://github.com/torvalds/linux/blob/master/drivers/usb/gadget/function/u_ether.c
- Linux mainline `cdc_ncm.c`: https://github.com/torvalds/linux/blob/master/drivers/net/usb/cdc_ncm.c
- Linux USB Gadget API: https://docs.kernel.org/next/driver-api/usb/gadget.html
