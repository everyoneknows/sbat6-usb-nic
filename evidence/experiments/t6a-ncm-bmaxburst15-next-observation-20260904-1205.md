# T6A CDC-NCM bMaxBurst=15 次仮説観測 — 2026-09-04 12:05 JST

## 確定済みの実機結果

- CDC-NCM bulk IN/OUT の host-visible `bMaxBurst=15` は確認済み。
- SuperSpeed を維持。
- 主方向 T6A → raspi4 の P1 は 1.32 Gbit/s、追加測定は 1.33 Gbit/s。
- Retr はいずれも 0。
- baseline 1.33〜1.34 Gbit/sに対する有意な改善はない。
- よって「`bMaxBurst=0` が約1.3 Gbit/s天井の単独主因」は棄却。相互作用の可能性は保留する。

## 現在状態の読み取り

指定された正規経路 `agent-101-vm → raspi2 → LAN/SSH → T6A T6A-MGMT-IP`
を使用した。ADB、USB serial、Zen3、物理ケーブル操作は行っていない。

12:05 JST のT6A read-only readback:

- Linux 5.4.238 / aarch64、4 CPU
- `ncm0`: `UP/LOWER_UP`, `192.168.250.1/30`
- `ncm0` 累積: RX 1,350,961,518 bytes / 1,301,509 packets、TX 3,490,618,568 bytes / 248,040 packets
- `ncm0` errors: RX 0、TX 0
- MTU3 USB IRQ (`11201000.usb`): CPU0に 5,410,449 件、CPU1〜3は0
- T6A側の通常ログ末尾に、今回のP1中のreset/disconnect/timeout/stallを示す記録なし

raspi4は同時刻のSSH接続がtimeoutしたため、host側の新規trace取得および状態変更は行わなかった。これはUSBリンク断の証拠とは扱わない。

## 仮説の再評価

1. **16KiB NTB + gadget wrap/aggregation** — 最優先。ローカルの対応ソースでは `NTB_DEFAULT_IN_SIZE=16384`、`NTB_OUT_SIZE=16384`、最大32 DPE。NTB生成時に skb allocation、NDP作成、payload copy、タイマーflushを行う。T6A固有 `ncm_wrap_ntb_mtk` の追加処理は未復元。
2. **request count / in-flight / MTU3 QMU-GPD batching** — 高優先。対応する `u_ether` 実装ではSuperSpeedの基本queue長が `DEFAULT_QLEN=2 × qmult` で、送受信request poolをspinlockで保護する。MTU3 IRQがCPU0に完全集中している実測と整合する。
3. **single queue / lock serialization** — 高優先。TX/RX request list操作とUSB queue投入が共通lockを通るため、burst拡大だけでは上位直列経路を越えない可能性がある。
4. **DMA/memcpy** — 中優先。NTB payload copyは確認済みだが、T6A vendor hook内部のDMA利用・copy回数は未確定。

## 次の実験条件

次回は **bMaxBurst=15、SuperSpeed、既存IP/MTU、T6A module/roleを維持**する。まずraspi4側の権限が利用可能になった時点で、usbmon/USB traceとP1を同時採取し、bulk transfer長分布、short/ZLP、完了間隔、in-flight URB近似、NTB/NDPのdatagram数を対応付ける。host側が再び到達不能なら、T6A側の設定変更や再bindは行わず停止状態を記録する。

traceでNTBが16KiB未満またはDPEが少数と判明した場合のみ、次の可逆実験として既存の許可済み経路で request queue/qmult またはNTB上限の候補を一つずつ変更し、変更前値へ復元してP1を比較する。改善が出た場合は `bMaxBurst=0/15` 交互作用A/Bを実施する。

## 変更・検証

- T6Aへの変更、再起動、再bind、モジュール操作なし。
- raspi4への変更なし。
- 実機readback後もT6A `ncm0` は `UP/LOWER_UP`、errors 0。
