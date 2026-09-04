# T6A USB NCM B班 runtime tuning — Windows Pavilion — 2026-09-04

## 前提と経路

測定経路は `raspi2 --LAN/SSH--> T6A`、USB NCM peer は Windows Pavilion
(`192.168.77.2`)。raspi4、`usb0`、ADBは使用していない。Windows側の
`iperf3.exe -s -B 192.168.77.2` を測定serverとして使用した。

各条件は T6A→Windows (`iperf3 -c 192.168.77.2 -t 10`) 3回、
Windows→T6A (`iperf3 -c 192.168.77.2 -R -t 10`) 3回を連続実施した。
送信方向の全試験で Retr=0。各変更後は直ちに元値へ復元した。

## 結果

| 条件 | T6A→Windows (Gbps) | Windows→T6A (Gbps) | 判定 |
|---|---|---|---|
| baseline | 1.36, 1.34, 1.35 | 1.02, 1.02, 1.02 | 基準 |
| `uether_tx_max_aggr_num=5` | 1.36, 1.37, 1.37 | 1.02, 1.02, 1.01 | 有意な改善なし |
| `u_ether_tx_req_threshold=2` | 1.36, 1.36, 1.34 | 1.02, 1.01, 1.02 | 改善なし |
| `tx_queue_len=2000` | 1.36, 1.38, 1.37 | 1.02, 1.02, 1.02 | 変動範囲内、採用せず |

## 復元後の検証

- `ncm0`: `UP, LOWER_UP`, MTU 1500、`fq_codel`、`tx_queue_len=1000`
- `uether_tx_max_aggr_num=10`
- `u_ether_tx_req_threshold=1`
- `qmult=30`, `tx_buff_num=0`, `uether_usb_request_qlen=80`
- `rx_errors=0`, `tx_errors=0`, `tx_dropped=0`
- qdisc backlog 0、drops 0、overlimits 0

## 結論

今回の安全なlive runtime候補3項目では、Windows Pavilionをpeerにした
約1.35Gbps (T6A→Windows)、約1.02Gbps (Windows→T6A) の基準を有意に
超える設定は確認できなかった。全変更は復元済み。`qdisc`は輻輳兆候が
ないため変更していない。`qmult`、`tx_buff_num`、
`uether_usb_request_qlen`はconnect-time作用のため、今回のlive-only試験
対象には含めていない。
