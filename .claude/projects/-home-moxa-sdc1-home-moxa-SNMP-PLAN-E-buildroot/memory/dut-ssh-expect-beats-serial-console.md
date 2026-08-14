---
name: dut-ssh-expect-beats-serial-console
description: 要在 DUT 上跑指令、或判斷在哪個 partition，走 SSH + expect 比序列埠安全；但 sshd 連幾次後會不再完成新 session
metadata: 
  node_type: memory
  type: project
  originSessionId: de421898-a940-4237-b2af-265dbd3454a1
  modified: 2026-08-05T05:51:39.657Z
---

DUT（192.168.127.253）**SSH port 22 是開的**，用 `expect` spawn `ssh -tt` 會配到
pty，所以 `moxash` 也能驅動——這正是 [[dut-console-is-linux-shell-not-moxa-cli]]
說序列埠 wrapper 會卡死的那個情境。**SSH 是獨立通道，卡住不影響 console**，
所以在不確定 DUT 在哪個 partition 時，SSH 是該先試的那條路。

登入 `admin`/`moxa`，`su` 密碼也是 `moxa`。落點本身就是 partition 判別式：
Plan E → Linux shell（`$`）；mainline → `moxash`（`moxa#`）。

**Why:** 2026-08-05 開場要確認 partition，handoff 說 mainline 上不能跑 `dut-console`。
SSH 探測一次就拿到答案，沒有碰序列埠。

**How to apply:**
- expect script 的 timeout 設 25~30s，外面再包 `timeout 60~90`，卡住就自己收掉。
- **已知限制：連幾次之後 sshd 就不再完成新 session**（TCP 仍 accept、ping 通、
  SNMP 正常，只有認證後卡住）。2026-08-05 第 1 次成功、第 2 次之後全部逾時。
  試三次就停手，改請使用者在 console 上跑，不要繼續打它。
- 指令輸出多行或含 `$`、`---` 這類字元時，expect 的 prompt 比對容易誤判，
  一次只跑一條、輸出壓到最短。
- 另一條零風險的 partition 判別式：13 個 mxPortdb OID 的往返時間——
  Plan E ≈ 13ms、mainline ≈ 258ms，差 20 倍。見
  [[snmpwalk-diff-confounded-by-dut-config]]。
