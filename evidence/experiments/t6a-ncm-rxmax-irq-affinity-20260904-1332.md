# T6A → raspi4 NCM receive-path A/B — 2026-09-04 13:27–13:32 JST

## Scope and safety

既知baselineを基準に、可逆なhost `cdc_ncm/rx_max` とT6A USB IRQ affinity
だけを一因子ずつ試験した。trace event、module、ConfigFS、USB role、GPIO、
VBUS、MTU、qdisc、物理接続は変更していない。

## Baseline and host receive buffer test

- Before: raspi4 `rx_max=16384`, `tx_max=16384`, `tx_timer_usecs=400`,
  `min_tx_pkt=13312`; both links UP/LOWER_UP, MTU 1500, qdisc `fq_codel`.
- Baseline P1: **1.35 Gbit/s**, Retr 0.
- Test: permitted `t6a-labctl ncm-set rx_max 8192`.
- Result: **6.18 Mbit/s receiver**, 7.74 Mbit/s sender, Retr 867.
  raspi4 `usb0` RX errors increased 1→251 during the test.
- Action: `rx_max=16384` restored and read back. No USB reset/disconnect was seen;
  wrapper log recorded `setting rx_max = 8192` then `16384`.
- Post-restore P1: **1.34 Gbit/s**, with transient Retr 399; link remained up.

Verdict: reducing host RX URB size below the advertised 16 KiB is strongly
deleterious, not an optimization. `rx_max=8192` is rejected as a candidate and
the 16 KiB value is retained.

## T6A USB IRQ affinity test

- Read-only before: IRQ 305 (`11201000.usb`), setting `0-3`, effective CPU0.
- Test: reversible write of IRQ 305 affinity to CPU1 (`smp_affinity=2`).
- Result: effective CPU1, P1 **1.33 Gbit/s**, Retr 0.
- Action: restored `smp_affinity=f`; readback setting `0-3`, effective CPU0.

Verdict: moving only the T6A USB IRQ from CPU0 to CPU1 produced no improvement
over the 1.30–1.35 Gbit/s baseline. IRQ affinity alone is downgraded. The
raspi4 xHCI IRQ remains CPU0-concentrated and was not changed because the
available wrapper does not authorize arbitrary root IRQ operations there.

## Static follow-up

The saved vendor-module disassembly still shows repeated `memcpy`,
`queued_spin_lock_slowpath`, `usb_ep_queue`, `crc32_le`, and hrtimer calls near
the NCM paths. This keeps copy/DMA and queue/serialization as the next analysis
targets, but no patch or module replacement is justified by these A/B results.
