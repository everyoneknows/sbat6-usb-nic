# T6A CDC-NCM USB trace observation — bMaxBurst=15 condition

日時: 2026-09-04 12:10–12:16 JST
経路: agent-101-vm → raspi2 → LAN/SSH → T6A `192.168.3.2`
対象: T6A MediaTek MTU3 gadget / `ncm0`
条件: 既存のSuperSpeed・host-visible bMaxBurst=15・`ncm0`設定を維持。変更なし。

## 接続状態

- kernel: `5.4.238`, AArch64
- `ncm0`: `UP`, `LOWER_UP`, carrier `1`, `192.168.250.1/30`, MTU `1500`
- UDC: `mtu3`, driver `g1`
- trace終了後も上記状態を再確認

## MTU3/QMU trace

T6Aのtracefsで、以下の読み取り観測用tracepointを一時的に有効化した。

- `mtu3_gadget_queue`
- `mtu3_prepare_gpd`
- `mtu3_complete_gpd`
- `mtu3_req_complete`
- `gadget/usb_ep_queue`
- `gadget/usb_gadget_giveback_request`

### 小さいトラフィック

`ping -c 8 192.168.250.2`:

- `ep5out` receive completion: 10件
- 実長: `156/16384` 8件、`100/16384` 2件
- `ep8in`: `128/128` 8件、`72/72` 2件
- `ep5out`の各completion後に、同じ16KiB要求枠を再queue

### 大きいping

`ping -A -s 1472 -c 100 -q 192.168.250.2`:

- 100/100成功、0% loss、平均RTT 3.486 ms
- `ep5out` completion: 100件、全て `1572/16384`
- `ep8in` completion: 100件、全て `1544/1544`
- 受信側は16KiB要求バッファを使うが、この負荷では実NTB転送長は約1.5KiB
- host→T6A方向で、100件の受信要求を観測。trace上のrequest pointerは62種類
- `ep5out` QMU ringは64 GPDエントリ（GPD.000–GPD.063）
- `ep8in` QMU ringも64 GPDエントリ
- `mtu3_qmu_isr`イベントはこのtrace設定では出現しなかった

## 判断

1. 16KiB NTB受信用のrequest length (`16384`) は実機traceで確定した。
2. request pool/QMU ringは少なくとも64 GPD規模であり、「受信request数が極端に1本だけ」という仮説は、T6A gadget側のリング観測とは整合しない。実際のhost-visible in-flight数はhost側usbmonで確定すべき。
3. 1472-byte pingでは各NTBが単一フレーム相当（1572 bytes）で、NDP aggregationは観測されなかった。これは高レートiperf時の16KiB NTB集約の有無を否定するものではない。
4. `ncm_wrap_ntb_mtk`内部のNDP集約状態、host側URB/in-flight供給、16KiB NTBの実転送長は、raspi4側usbmonまたはUSB traceが必要。T6A側traceだけではNDPテーブル内容を読めない。

## 復旧

一時的に有効化した個別tracepointは無効化した。tracefsの常時トレース状態は観測前の有効状態へ戻し、最終確認で `tracing_on=1`、`events/enable=1`。USBリンク、gadget bind、`ncm0`、bMaxBurst、SuperSpeedには変更なし。

## 次の優先仮説

次は、host側usbmonが取得可能になった時点で、同じbMaxBurst=15/SuperSpeed条件のiperf P1について、16KiB NTBの実長分布、NDP datagram数、bulk IN URBの要求長・完了長・同時Outstanding数を対応付ける。現観測からは、T6A gadget側の固定16KiB receive bufferや64-entry QMU ringより、NDP集約が実際に成立しているか、host側URB供給とデータパス（copy/DMA）の寄与を優先する。
