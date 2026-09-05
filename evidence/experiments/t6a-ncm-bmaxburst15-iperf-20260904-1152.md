# T6A ↔ raspi4 CDC-NCM bMaxBurst=15 throughput verification — 2026-09-04 11:52 JST

## 判定

- 通信路復元後の疎通確認は成功。
- `bMaxBurst=15` は raspi4 host-visible descriptor の CDC-NCM data endpoint
  8 IN / 5 OUT の両方で維持されている。
- 既往と同一条件の主評価（raspi4 → T6A、reverse iperf3）は成功し、
  10秒平均 `1.01 Gbit/s` を記録した。
- 測定後、今回起動したraspi4側のiperf3 serverは停止した。

## 接続復元と確認

経路は `agent-101-vm -> raspi2 -> T6A T6A-MGMT-IP` と、指定された
専用鍵による `kuroko-lab@192.168.0.89` のみを使用した。

T6A:

```text
ncm0 UP, LOWER_UP
192.168.250.1/30
```

raspi4:

```text
usb0 UP, LOWER_UP
carrier=1
192.168.250.2/30
tx_timer_usecs=400
tx_max=16384
rx_max=16384
min_tx_pkt=13312
```

raspi4側のIPv4は、重複確認を内包する許可済み専用wrapperで追加した。

```text
sudo -n /usr/local/sbin/t6a-labctl lab-ip-on
```

T6Aから `ping -I ncm0 -c 3 -W 2 192.168.250.2` を実行し、3/3成功、
0% loss、RTT min/avg/max `3.552/4.589/6.421 ms` だった。

## bMaxBurst実測

raspi4で `lsusb -v -d 2c7c:7006` を再確認した。
CDC-NCM data interfaceのbulk endpointは次のとおり。

```text
EP 8 IN:  wMaxPacketSize=1024, bMaxBurst=15
EP 5 OUT: wMaxPacketSize=1024, bMaxBurst=15
```

`cdc_ncm`のsysfs値は既知の基準値（上記4値）から変化していない。
module、descriptor、USB再bind、再起動は行っていない。

## iperf3主評価

T6Aで次を実行した。

```text
iperf3 -c 192.168.250.2 -R -t 10
```

結果:

- 接続: `192.168.250.1:37140 -> 192.168.250.2:5201`
- reverse、データ送信元はraspi4
- 転送量: sender `1.18 GBytes` / receiver `1.17 GBytes`
- 平均: `1.01 Gbits/sec`
- Retr: `115`（sender表示）
- 終了コード: 0
- 1秒間隔: `965 Mbit/s, 1.02, 1.01, 1.01, 1.01, 1.01, 1.02, 1.01, 1.02, 1.01 Gbit/s`

測定後のT6A `ncm0` は `UP / LOWER_UP / 192.168.250.1/30` を維持し、
raspi4 `usb0` も `carrier=1` を維持した。raspi4側iperf3 serverは停止済みで、
専用実験アドレスは次の疎通評価に必要なため維持している。

測定中に新たなUSB reset/disconnect、stall、timeoutは確認しなかった。
なお、dmesgには測定以前のUSB再列挙履歴が残っているため、過去履歴を測定中の
異常とは扱っていない。
