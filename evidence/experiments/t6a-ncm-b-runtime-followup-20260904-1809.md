# T6A USB NCM B班 runtime tuning follow-up — 2026-09-04

## Access and safety

操作経路は `agent-101-vm -> raspi2 -> SSH root@192.168.3.2` のみ。ADB、raspi4
経路、UDC/configfs操作、rebind、module reload、rebootは行っていない。

## Windows host autonomous measurement

T6A側から `iperf3 -c 192.168.77.2 -t 2 --json` を実行し、Windows Pavilion
のiperf3 serverへの接続を確認した。初回はserverが別試験中でbusyだったが、
再試行は完走し、T6A→Windowsは1.316 Gbps、Retransmit 0だった。
その後の再試行ではserverが継続して `server is busy running a test` を返した。
5201/TCPがLISTENしていない状態ではないため、server停止・切断は行っていない。

## Live T6A state

* `ncm0`: `UP, LOWER_UP`, `192.168.77.1/24`, MTU 1500
* qdisc: `fq_codel`, qlen 1000
* qdisc cumulative counters: drops 0, overlimits 0, requeues 413, backlog 0b/0p
* netdev counters at observation: RX errors 0/dropped 5819; TX errors 0/dropped 0
* queues: one RX/TX queue; RPS mask `0`, XPS empty
* module values: `uether_tx_max_aggr_num=10`, `u_ether_tx_req_threshold=1`,
  `tx_buff_num=0`, `uether_usb_request_qlen=80`, `qmult=30`
* CPU governor: `schedutil`; max 2.2 GHz; observed current frequencies 0.666–1.61 GHz
* thermal sensors: approximately 50–63 C for the reported CPU/SoC-related zones

## Runtime candidate attempt

`uether_tx_max_aggr_num=5` was written through its existing sysfs module-parameter
interface and read back as 5. The first partial sequence produced T6A→Windows
values 1.352, 1.357, and 1.370 Gbps, and reverse values 1.014 and 1.014 Gbps;
the sequence was interrupted by the Windows server becoming busy. The parameter
was restored to 10 and verified. A subsequent three-run sequence at 5 failed
only because the remote server remained busy; no throughput result was accepted
from those failed runs.

No other candidate was changed. In particular, no claim is made for values
12/16/20/32 without three complete runs per direction.

## Static interpretation

The saved vendor object has the parameter as a writable `uint` module parameter,
but its stripped vendor code does not retain source-level names for the internal
data-path consumers. Existing binary reconstruction does establish that NCM
TX wrapping builds a 16 KiB NTB, copies datagram payloads, and flushes on size/
timer conditions. Therefore increasing an aggregation-count limit above about
10 cannot create additional frames inside the already negotiated 16 KiB NTB;
whether it controls a separate vendor request/packet limit remains unproven.
The `u_ether_tx_req_threshold` consumer is likewise not source-identifiable
from the saved object alone.

## Decision

The Windows server is the only remaining measurement gate. qdisc is not a
priority candidate because live backlog is zero and drops/overlimits are zero.
The current T6A state was left at baseline values. To complete the requested
three-run A/B matrix, Windows must finish its current iperf3 test; if it is not
intended to remain active, start it explicitly with:

`iperf3.exe -s -B 192.168.77.2`
