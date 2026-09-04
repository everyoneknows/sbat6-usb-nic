# T6A USB実験の再分類（2026-09-03）

一次証拠は `/home/masataka/projects/sbat6-usbnet/evidence/`、ビルド成果物、ABI監査TSVを参照する。以下の整理は、SHAだけでなく実機状態・物理観測・ABIを分離して扱う。

## BEFORE snapshot

- FACT: T6Aは Linux 5.4.238 aarch64。根拠: `live-readonly-20260903.txt`。
- FACT: `lsusb` はroot hubのみ、USB cable/deviceは未接続。根拠: `vbus-off-reproduction-20260903.md`。
- FACT: `sbat6_usb_role_min.ko` の実機ロード記録のSHA256は `bc8db83886315ccd346e75abd07ce08d0d8b63a4a2f24a80121c25d452dce78f`、`INSMOD_RC=0`。根拠: `helper-load-unload-20260903.txt`。
- FACT: `usb_f_ncm.ko` の `80c8103ac6112ffa014076fa1e09f18584e60839f729bd9d9fe6c87e9eec37e9` は `module_layout` が `0x6006b85e`。根拠: `logs/abi-audit.tsv.versions`。

## ACTION

MTU3の正規mode経路で `mode=1`、続いて `mode=3`。この記録の目的はHOST→DEVICE待機状態の再現であり、ケーブル接続・enumeration・NCM通信は実施していない。

## AFTER snapshot

- FACT: `mode=3`、UDC `state=not attached`、`function=g1`、`current_speed=UNKNOWN`、xHCI platform device absent。根拠: `vbus-off-reproduction-20260903.md`。
- FACT: `sbat6_usb_role_min.ko` はロード済み・`[permanent]`で、unloadは失敗。根拠: `helper-load-unload-20260903.txt`。
- FACT: `80c810…` NCMはvendor ABI `0x3a3eb6e9` と `0x6006b85e` が不一致。根拠: `logs/abi-audit.tsv` と `logs/versions.tsv`。

## physical observation

- FACT: `PHYSICAL: USB-A VBUS-GND=0V, measured by旦那さま; USB cable未接続`。根拠: `helper-load-unload-attempt-20260903.txt` の状態訂正。
- UNKNOWN: host側のVBUS供給、xHCI経由のattach、UDC bind後のenumeration、NCM通信。

## verdict

- FACT: DEVICE待機状態と0Vという観測は確認できる。
- INFERENCE: 未接続なら0VはhostからVBUSが供給されていない状態と整合する。
- HYPOTHESIS（反証）: 「0V = USB DEVICE成功」は反証。0VだけではDEVICE化・enumerationを示さない。
- verdict: `UNKNOWN`（USB DEVICE成功ではない）。物理観測とソフトウェア表示に同一キーの矛盾が出た場合は `STOP` とする。

## known-good表現の訂正

- `sbat6_usb_role_min.ko` (`bc8db838…`): 実機でロードされたhelperおよびmode遷移の関連証拠はある。しかし vermagic、module_layout CRC、全ABI照合、成功操作を一つのmanifestで揃えたUSB成功証拠ではない。`known-good` は撤回し、`historical-loaded-helper` とする。
- `usb_f_ncm.ko` (`80c810…`): source auditとSHAは保存されているが、vendor ABI監査で `module_layout`を含む不一致がある。`known-good` は撤回し、`historical-abi-mismatch` とする。
- `usb_f_ncm-vendor-abi-20260903.ko` (`833c8a3f…`): ABI監査は全項目MATCHであるが、実機enumeration・NCM通信の成功操作は未実施。`ABI-compatible candidate` であり、まだknown-goodではない。

## 終了要約

- confirmed facts: T6A mode=3、UDC not attached、xHCI absent、VBUS 0V、helper SHA、NCM旧CRC不一致。
- disproved hypotheses: 0V単独でDEVICE成功、旧NCM SHAだけでknown-good。
- unresolved questions: host VBUS、cable接続後のenumeration、UDC bind、NCM通信。
- next safest experiment: ケーブル未接続を確認した上で、成功条件（VBUS、UDC、xHCI、host enumeration、NCM通信）を先に宣言し、物理測定を別系統で採取してから一回だけ接続試験。高リスクなrole/GPIO/register/DT変更は明示承認なしに行わない。
