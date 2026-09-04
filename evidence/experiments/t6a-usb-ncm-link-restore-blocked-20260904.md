# T6A ↔ raspi4 CDC-NCM link restore attempt — 2026-09-04

## Scope

旦那さまの指示に従い、既知の `bMaxBurst=15` 状態を維持したまま、T6A側
`ncm0` の通常通信設定復元とraspi4側carrier確認へ進もうとした。
descriptor、module、USB再bind、再起動、IP設定変更は行っていない。

## T6A access result

- raspi2の既存ADB端末 `GCAZCY05P824JAW` は `ASUS_Z012DA`（Zen3）であり、
  T6Aではなかった。
- raspi4にはT6A（Quectel `RG620T-SBK`, `2c7c:7006`）がUSB接続され、
  `/dev/ttyACM0..2` と `usb0` が見えている。
- `kuroko-lab`にはTTY読取り権限がなく、許可済み
  `/usr/local/sbin/t6a-labctl` にもT6A側の `ip link` / `ip addr` 操作はない。
- したがって、別機器であるZen3を誤操作せず、T6A側の `ncm0 up` と
  `192.168.250.1/30` 設定は未実施。

## raspi4 observation

専用鍵・`IdentitiesOnly=yes`でraspi4へ接続し、許可済みwrapperと読み取り専用
sysfs/ip情報を確認した。

- `usb0`: `UP` flagだが `state DOWN`, `NO-CARRIER`
- carrier: `0`
- `operstate`: `down`
- `carrier_changes`: `3`
- MTU: `1500`
- IP address: 未設定
- cdc_ncm: `tx_timer_usecs=400`, `tx_max=16384`, `rx_max=16384`,
  `min_tx_pkt=13312`（既知の復元値）
- counters: RX `336` bytes / `12` packets、TX `2815` bytes / `15` packets

直近kernel logではCDC-NCM `usb0` の登録後、複数回のUSB disconnect/reconnectが
発生している。最新の再列挙では `cdc_ncm`登録まで確認できるが、carrier成立は
確認できない。CDC notificationの生データは採取できていない。

## Verdict

`STOP — T6A側設定経路不足かつcarrier=0`。

通信路が成立していないため、raspi4への `192.168.250.2/30` 設定、iperf測定、
host側設定変更は行わない。次に必要なのは、T6A上で通常ユーザーまたは既存の
専用操作経路から次の2操作を実行できることの確認である。

```text
ip link set ncm0 up
ip addr add 192.168.250.1/30 dev ncm0
```
