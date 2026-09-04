# T6A `usb_net.ko` bMaxBurst 参照先再解析 — 2026-09-04

## 結論

前回の file offset `0x10c52` は、hostへ提示されるCDC-NCMのSuperSpeed bulk
companionではなかった。実際のNCM SS descriptor arrayは `.data+0x7f0` で、
bulk IN/OUTが共有する `usb_ss_ep_comp_descriptor` は `.data+0xa48`、すなわち
file offset `0x10fd0` にある。`bMaxBurst` はその3バイト目、file offset
`0x10fd2` である。

T6Aへの追加patch、再ロード、再試験は行っていない。

## 全候補の探索

`.data` は file offset `0x10588`、size `0xa5f`。`06 30` を先頭とする
6-byte候補、および隣接するdescriptor構造を全探索した結果は以下の通り。

| file offset | `.data` offset | bytes | 判定 |
|---:|---:|---|---|
| `0x108f8` | `+0x370` | `06 30 04 00 00 00` | RNDIS/別functionのSS bulk companion候補、`bMaxBurst=4` |
| `0x108fe` | `+0x376` | `06 30 00 00 08 00` | 同functionのnotify companion候補 |
| `0x10c50` | `+0x6c8` | `06 30 00 00 00 00` | 別functionのSS bulk companion候補、今回のNCM bind配列外 |
| `0x10c56` | `+0x6ce` | `06 30 00 00 10 00` | 同じ別functionのnotify companion候補 |
| `0x10fd0` | `+0xa48` | `06 30 00 00 00 00` | **NCM SS bulk companion。IN/OUT共有** |
| `0x10fd6` | `+0xa4e` | `06 30 00 00 10 00` | NCM SS notify companion |

完全一致 `06 30 00 00 00 00` は `0x10c50` と `0x10fd0` の2箇所だけ。
`0x10c52` と `0x10fd2` は、いずれも対応descriptorの `bMaxBurst` byteである。

## NCM bindからhostまでの参照経路

シンボル名は大部分が消えているが、`ncm_mod_init`、関数object、relocation、
call siteは残っている。

1. `ncm_mod_init` (`.text+0x71a8`) は `.data+0x6e0+0x248` を
   `usb_function_register()`へ渡す。
2. NCM bind相当の関数は `.text+0x1940` から始まる。冒頭でNCM function
   objectを `.data+0x6e0` としてロードする。
3. bind内の `usb_assign_descriptors` call は `.text+0x1ba4`。
   AArch64の引数設定は次の通り。

   ```text
   fs = .data+0x6e0+0x1e8 = .data+0x8c8
   hs = .data+0x6e0+0x188 = .data+0x868
   ss = .data+0x6e0+0x110 = .data+0x7f0
   ssp = .data+0x6e0+0x110 = .data+0x7f0
   ```

   根拠は `.text+0x19d8` の `.data+0x6e0` relocation、続く
   `add x4,#0x110`、`add x2,#0x188`、`add x1,#0x1e8`、および
   `.text+0x1ba4` の `R_AARCH64_CALL26 usb_assign_descriptors`。

4. SS array `.data+0x7f0` の `.rela.data`は、ソース上の順序と一致する。

   ```text
   IAD, control interface, CDC header, union, Ethernet, NCM,
   SS notify EP, notify comp(.data+a4e), data alt0, data alt1,
   bulk IN EP(.data+7ce), bulk comp(.data+a48),
   bulk OUT EP(.data+7d7), bulk comp(.data+a48), NULL
   ```

   具体的なrelocationは `.rela.data+0x7f0` から始まり、
   `+0x828 -> .data+a4e`、`+0x848 -> .data+a48`、
   `+0x858 -> .data+a48`。従ってbulk IN/OUTは同一objectを参照する。

5. `usb_assign_descriptors()`は5.4.238の実装で、SS arrayを
   `usb_copy_descriptors()`へ渡し、descriptorをheapへbyte-copyする。
   コピー時に `bMaxBurst`を書き換える処理はない。

6. `config_ep_by_speed_and_alt()`はSS arrayを走査し、endpoint直後の
   companionを取得して `_ep->comp_desc` に設定する。同時に
   `_ep->maxburst = comp_desc->bMaxBurst + 1` とする。
   `config_ep_by_speed()`はこのwrapperであり、値を0へ戻さない。

7. MTU3 `mtu3_ep_enable()`は `mep->comp_desc` を読み、
   `burst = comp_desc->bMaxBurst` として `mtu3_config_ep()`へ渡し、
   その後 `mep->ep.comp_desc = comp_desc` と保存する。ここにもdescriptor
   byteの上書きはない。

8. USB configuration生成時は `function_descriptors(f, speed)` が
   `f->ss_descriptors`を返し、`usb_descriptor_fillbuf()`がその内容をhost
   responseへコピーする。従ってNCM SS bulk descriptorのhost-visible生成元は
   `.data+a48`由来のheap copyである。

## `bMaxBurst=0` の由来

`0x10fd0` のstatic objectは、`.bLength=6`、`.bDescriptorType=0x30`以外が
指定されておらず、file上の `bMaxBurst` byte `0x10fd2` は0である。
これはBSSではなく、`.data`に配置されたstatic初期値である。bind時の
`usb_copy_descriptors()`はこの0をコピーし、MTU3はその0を読むだけである。
runtime overwrite、descriptor copy後の0への再設定、MTK独自の別生成は、
確認した5.4.238コード経路には存在しない。

## `0x10c52` の正体

`0x10c50` は `.data+0x6c8` の別descriptor objectである。`.rela.data`の
`+0x4d8` と `+0x4e8` が `.data+0x6c8` を共有するため、何らかの別functionの
bulk IN/OUT候補であることは確定する。しかしNCM bindが渡すSS array
`.data+0x7f0`には含まれず、NCM bulkの実体ではない。したがって前回の
`00 -> 0f` は正常にロードされても今回のNCM host descriptorを変更しなかった。

## 次の最小patch候補（オフラインのみ）

```text
対象: 解析用 original usb_net.ko
変更: file offset 0x10fd2 の 00 -> 0f
対象object: .data+0xa48 / NCM SS bulk companion
共有先: SS bulk IN と SS bulk OUT
除外: 0x10c52、0x10fd2以外の全byte、notify companion
```

これは参照経路が確定した後の解析用候補であり、T6Aへは適用していない。
次回実機試験を行う場合も、まずhost `lsusb -v`でbulk IN/OUT双方が15になる
ことだけを確認し、異常がなければ通信試験へ進む。

## 根拠ファイル

- `analysis/t6a-usb_net/t6a-usb_net.original.ko`
- `analysis/t6a-usb_net/disasm.txt`
- `analysis/t6a-usb_net/t6a-usb_net.original.ko.readelf-r.txt`
- `analysis/t6a-usb_net/t6a-usb_net.original.ko.readelf-S.txt`
- `/home/user/projects/sbair6-rce/work/src/linux-5.4.238-ax88179/drivers/usb/gadget/config.c`
- `/home/user/projects/sbair6-rce/work/src/linux-5.4.238-ax88179/drivers/usb/gadget/composite.c`
- `/home/user/projects/sbair6-rce/work/src/linux-5.4.238-ax88179/drivers/usb/mtu3/mtu3_gadget.c`
