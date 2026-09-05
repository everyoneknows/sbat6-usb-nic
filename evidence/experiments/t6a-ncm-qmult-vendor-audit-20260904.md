# T6A CDC-NCM qmult → gadget request queue 静的監査 — 2026-09-04

## 結論

`qmult=30` が表示されることだけでは、T6A の実行中 vendor
`usb_net.ko` が各方向60本の request を用意している証拠にならない。

保存された upstream相当 source では、SuperSpeed時に
`DEFAULT_QLEN=2` と `qlen=qmult*2` を使い、`gether_connect()` が
TX/RX双方へ同じ本数を `prealloc()` する。しかし、このsourceは
実機で動作した vendor `usb_net.ko` のsourceではない。

## 確認した事実

- `./source/u_ether.c` は、保存された
  Linux 5.4.238 sourceとSHA256が一致する。
- 同sourceの `qlen()` は、High/SuperSpeedで `qmult * DEFAULT_QLEN`、
  `DEFAULT_QLEN=2` を返す。
- `gether_connect()` は `alloc_requests(dev, link, qlen(...))` を呼び、
  `alloc_requests()` はTX/RX双方を同じ本数 `prealloc()` する。
- ConfigFSの `qmult` show/store は `gether_get_qmult()` /
  `gether_set_qmult()` を呼ぶ。未接続時に設定された値は、connect時に
  `dev->qmult` から参照される構造である。
- upstream mainlineにも同じ基本構造があり、`qlen()` はSuperSpeedで
  `qmult * DEFAULT_QLEN` を返す。
- 一方、実機で使われた保存済み vendor `usb_net.ko` のELFには、
  `alloc_etherdev_mqs`、`ppe_usb_resume_queue_hook`、
  `ppe_usb_suspend_queue_hook` などvendor固有経路が存在する。
  `gether_connect` は標準sourceの単純な対応物ではなく、保存disassembly上
  で追加の転送サイズ更新・vendor処理を含む。
- vendor moduleの保存disassemblyでは `qlen` が独立symbolとして残って
  おらず、実際の request 本数を静的に60と断定できる命令列まではまだ
  対応付けられていない。
- `qmult=30`、SuperSpeed、host側64本級のrequest観測は既存FACTだが、
  host側request数はT6A gadget TX側request数の証明ではない。

## 判断

第一容疑者を「ConfigFSの値が失われる」から、より具体的に
「vendor `usb_net.ko` のconnect時 queue計算またはその後のvendor/QMU
投入が、標準u_etherの60本モデルと異なる」に更新する。

現時点で安全な変更を伴わずに断定できるのは、次の範囲である。

1. upstream相当実装なら、qmult=30かつSuperSpeedで各方向60 request。
2. T6A vendor実装が同じ結果になることは未証明。
3. host側usbmonの64本級観測は、T6A側TX poolの本数を示さない。

## 次の最小観測

T6Aへのアクセス経路が利用可能な接続時に、同一接続を維持したまま、
既存のread-only wrapperで以下を同時採取する。

- vendor moduleの実体SHA、vermagic、依存関係
- `qmult` readbackとUDC speed
- MTU3 endpointのrequest list / QMU outstandingが取得可能か
- `/proc/interrupts`、MTU3/QMU debugfsまたは既存tracepointに
  request投入・完了カウンタがあるか
- usbmon captureのsubmit/complete時系列。ただしcapture境界差分を
  steady-state本数とは扱わない

request本数を直接数えられない場合は、vendor moduleのdisassemblyで
`gether_connect` → queue計算 → `usb_ep_alloc_request` / `usb_ep_queue`
の呼出しを再構成し、標準sourceとの差分を確定する。module交換、再bind、
ConfigFS変更、NTB変更はこの監査の成功条件ではなく、先送りする。

## アクセス状態

今回の監査中、raspi2へのSSHは成功したが、raspi2からT6A
`root@T6A-MGMT-IP` への公開鍵認証は `Permission denied` となった。
T6Aの設定・module・通信状態は変更していない。
