# T6A CDC-NCM 通常通信状態復元と host 実測記録 — 2026-09-04 11:49 JST

## 判定

- `bMaxBurst=15` の host-visible 実測確認は **SUCCESS** として記録する。
  根拠は既存の raspi4 follow-up 記録で、CDC-NCM bulk IN/OUT の両方が
  `wMaxPacketSize=1024`, `bMaxBurst=15` と確認されていること。
- module、descriptor、USB再bind、再起動は本作業で扱っていない。
- T6A `ncm0` の通常通信状態復元は成功。
- raspi4 `usb0` の carrier は `0 -> 1` に復帰した。
- raspi4 の IPv4 peer address が未設定のため、iperf3 は未実施。

## 実施

正規経路 `agent-101-vm -> raspi2 -> T6A-MGMT-IP` の configured SSH identity
鍵で T6A を識別した後、T6A root 上で指定された操作のみを実行した。

```text
ip link set ncm0 up
ip addr add 192.168.250.1/30 dev ncm0
```

T6A直後の確認:

```text
ncm0 UP, LOWER_UP
192.168.250.1/30
operstate=up
carrier=1
```

指定SSH経路で raspi4 の既存状態を再確認した結果:

```text
usb0 UP, LOWER_UP
operstate=up
carrier=1
carrier_changes=4
```

raspi4 `usb0` には IPv6 link-local のみがあり、`192.168.250.2/30` は存在しなかった。
iperf3 server (`*:5201`) は稼働していた。

## 権限制約と停止理由

raspi4 の `kuroko-lab` で指定された無権限の追加を確認したが、結果は次のとおり。

```text
ip addr add 192.168.250.2/30 dev usb0
RTNETLINK answers: Operation not permitted
```

変更後も `usb0` の既存状態は維持され、意図しない設定変更はない。
許可済みsudoは `/usr/local/sbin/t6a-labctl *` のみで、任意の `ip addr`
設定経路は提供されていない。このため raspi4 peer IPv4 を捏造せず、iperf測定は
ここで停止した。

## CDC notification を推定できる観測

生のCDC notification payloadは採取していない。利用できる関連情報は以下。

- raspi4 kernel log は対象を `2c7c:7006` / `Quectel RG620T-SBK` として認識。
- SuperSpeed列挙後に `cdc_ncm` が `usb0` を登録。
- T6A側 `ncm0` が `LOWER_UP` / carrier=1 になった後、raspi4側も
  `LOWER_UP` / carrier=1 になった。
- raspi4側driverは `/sys/bus/usb/drivers/cdc_ncm`。
- 直近のログに登録後の新たな disconnect/reset/stall/timeout はない。

従って、CDC-NCMのcontrol/data link成立は状態遷移から推定できるが、notification
の個別コードを確認したとは主張しない。

## 次に必要な最小操作

raspi4側で管理者権限により、既存の一時設定として次を実行できれば、同じ状態確認後に
iperf3測定へ進める。

```text
ip addr add 192.168.250.2/30 dev usb0
```
