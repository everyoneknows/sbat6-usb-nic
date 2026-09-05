# T6A CDC-NCM A班 observation-only candidate — aborted during ConfigFS teardown

実施時刻: 2026-09-04 22:05–22:14 JST
経路: `agent-101-vm -> raspi2 -> root@T6A-MGMT-IP`。ADB、runtime2、flashは未使用。

## 結果

candidate投入前、UDCをunbindし、configuration `f1`〜`f5` のsymlinkを解除した。
各解除後も `usb_net` は `77824 6` のままだった。既存function全解体に進み、
`rmdir .../functions/acm.gs0` がD-state（uninterruptible sleep）で停止したため、
追加削除・`rmmod`・candidate load・性能試験を中止した。force rmmodは実行していない。

解体中の内訳は、構成上の `acm.gs0`、`acm.gs1`、`acm.gs2`、`ffs.adb`、
`mass_storage.usb0`、`ncm.gs8`、`ecm.gs8`、`rndis.gs4` が存在し、configurationに
`f1=acm.gs2`、`f2=ffs.adb`、`f3=acm.gs0`、`f4=acm.gs1`、`f5=ncm.gs8` が接続されていた。
`f1`〜`f5`のunlink後もrefcountは各回6。停止点は`acm.gs0`のrmdir。

## Candidate artifacts

- telemetry sink: `94b157ad17cbe678f2484d058b2e5f8231e5ed6de6fe33f8349ee1588ca6ebf5`
- observation-only `usb_f_ncm.ko`: `d2257ff360fa82c6f2ea639a9856ebd5db7e018b1e71c1113eb74e48ffe7e783`
- いずれもロードされていない（再起動後も`lsmod`に不在）。

## Recovery

ConfigFS解体がハングしたため通常再起動へ移行。再起動後にvendor `usb_net`が
`refcount=6`で復帰した。既知の正規sysfs経路で`mode=3`、GPIO322 LOW、
`f5 -> ncm.gs8`、UDC bindを再設定した。

最終確認:

- 管理LAN: `br-lan UP T6A-MGMT-IP/24`
- xHCI: mode=3後にplatform deviceなし
- mode=`3`
- GPIO322=`0`
- UDC=`11201000.usb`, state=`configured`, current_speed=`super-speed`
- VID/PID=`2c7c:7006`, bcdUSB=`0x0320`, bcdDevice=`0x0223`
- NCM MAC: device `02:00:00:00:00:01`, host `02:00:00:00:00:02`, qmult=`30`
- `ncm0 UP 192.168.77.1/24`, carrier=`1`
- Windows `192.168.77.2` ping: 3/3、0% loss
- vendor `usb_net`: `77824 6`

再起動前のdmesg末尾に、この実験由来のOOPS/BUG/call traceは確認されなかった。
ただしConfigFS `rmdir`のD-stateハング自体が異常であり、candidate性能測定は未実施。
再起動により再起動前dmesgの完全な保持はできていない。

## Rollback

`/root/butlerx-t6a-rollback.sh` をT6Aへ事前配置済み。vendor module再ロード、
NCM function再生成、f5復元、mode=3、GPIO322 LOW、UDC bind、IP設定を含む。
実際の復旧はより確実な通常再起動と正規rebindで完了した。

## Decision

`ABORTED_BEFORE_CANDIDATE_LOAD`。次に変更すべき1項目は、ACM/FFS/mass-storage等の
既存functionを削除せず、vendor providerのrefcount 6の所有者を特定して安全に解放する
専用手順を作ること。32KiB NTB変更やforce rmmodへは進めない。
