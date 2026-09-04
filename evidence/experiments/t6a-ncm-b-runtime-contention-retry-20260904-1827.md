# T6A USB NCM B班 — Windows server contention retry and source follow-up

## 前提と経路

Windows Pavilion の `iperf3.exe -s -B 192.168.77.2` は既に起動済みとし、
停止・再起動は行わなかった。管理経路は `raspi2 -> LAN/SSH -> T6A` のみで、
raspi4、`usb0`、ADBは使用していない。

## busy再試行の実測

T6A上で各試験を実行し、失敗時は3秒間隔で再試行した。`server is busy
running a test` はserver停止ではなく競合として扱った。

| 試験 | 成功まで | 成功結果 |
|---|---:|---|
| 短試験 `-t 2` | 1回目 | 1.36 Gbit/s、Retr 0 |
| F1 `-t 10` | 1回目 | 1.36 Gbit/s、Retr 0 |
| F2 `-t 10` | 1回目 | 1.37 Gbit/s、Retr 0 |
| F3 `-t 10` | 9回目（8回busy） | 1.37 Gbit/s送信、1.36 Gbit/s受信、Retr 0 |
| R1 `-R -t 10` | 1回目 | 1.02 Gbit/s送信、1.01 Gbit/s受信 |
| R2 `-R -t 10` | 1回目 | 1.02 Gbit/s送信、1.02 Gbit/s受信 |
| R3 `-R -t 10` | 1回目 | 1.03 Gbit/s送信、1.02 Gbit/s受信 |

F1〜F3のT6A→Windows平均は約1.37 Gbit/s、R1〜R3のWindows→T6A平均は
約1.02 Gbit/sで、既存baseline（約1.35–1.36 / 約1.02 Gbit/s）からの
有意な変化はない。busy後もserverは空き、短間隔再試行で測定へ移行できた。

## 測定後のT6A状態（2026-09-04 18:27 JST）

- `ncm0`: `UP`, `LOWER_UP`, `192.168.250.1/30`, `192.168.77.1/24`
- carrier: `1`、MTU: `1500`、qdisc: `fq_codel`、tx queue length: `1000`
- `uether_tx_max_aggr_num=10`
- `u_ether_tx_req_threshold=1`
- `tx_buff_num=0`
- `uether_usb_request_qlen=80`
- netdev errors: RX/TXとも `0`、TX dropped `0`

## 指定項目の解析結果

### `uether_tx_max_aggr_num`

vendor ELFにはwritableなuint module parameterが存在する。文字列には
`max_pkts`、`aggregate the packet`、`aggr`のログ痕跡があり、TX NCM wrapping
のpacket/aggregation上限に関係する候補である。ただし保存ELFのstrip済み
data pathでは、runtime parameter値を読む正確なconsumer位置と、16KiB NTBの
packet上限との対応は完全には復元できない。値5は既にWindows経路で3回×両方向
を実施済みで、baseline超えなし。現在値10へ復元済み。

### `u_ether_tx_req_threshold`

vendor ELFにはwritableなuint module parameterがあるが、保存ELFからsource-level
consumerは特定できない。従ってrequest完了数、free-list、aggregation flushの
どれを閾値化するかは未確定。値2のWindows A/Bは既に完了し、改善なし。現在値1。

### `rx_max`

これはT6A vendor module parameterではなく、host Linux `cdc_ncm`のRX側最大NTB
サイズである。`cdc_ncm_check_rx_max()`はdeviceが通知する
`dwNtbInMaxSize`を上限にclampし、`cdc_ncm_update_rxtx_max()`はdeviceへ
`SET_NTB_INPUT_SIZE`を送り、hostの`rx_urb_size`を更新する。running中はRX URBを
unlinkして再構成するため、単なる表示値ではない。16KiB未満の8192は既試験で
6.18Mbps、Retr 867、host RX error増加となり、16384へ復元済み。改善候補から
除外する。

### runtime反映可能な残りparameter

現行T6Aでsysfs read/write可能なのは少なくとも `tx_buff_num`、
`uether_tx_max_aggr_num`、`u_ether_tx_req_threshold`、`uether_usb_request_qlen`
等。ただし `uether_usb_request_qlen`、`qmult`、`tx_buff_num` はconnect/rebind
時のrequest allocationへ作用するため、live-only変更では反映を証明できない。
`qmult=30`もvendor実装ではupstreamの60本/方向を意味しない。既に
`tx_buff_num` 0/32/64/80、`uether_tx_max_aggr_num=5`、
`u_ether_tx_req_threshold=2`、`tx_queue_len=2000`を評価済みで、採用候補なし。
残りの安全なlive-only candidateは、現時点では再試験する価値のある未評価値が
確認できない。request pool実数、NTB packing、copy回数、completion間隔の測定を
優先する。

## 判定

Windows serverは停止していない。今回の8回busy後の成功を含め、busyを競合と
して再試行する運用を実証した。T6Aはbaselineへ維持され、追加のruntime変更は
行っていない。
