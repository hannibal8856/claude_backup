---
name: feedback-dut-operation-authorization
description: "使用者已授權我直接操作 DUT(192.168.127.253)三個等級 A/B/C,含 swupdate 燒錄;但 examinate-plan-e-swu 的兩道 gate 不因此放寬"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 13f6131f-3289-46a0-9662-a2a36f544e35
  modified: 2026-08-06T08:39:11.918Z
---

2026-08-06 使用者明示授權我直接在 DUT(`192.168.127.253`)執行指令,**不必每次先問**:

| 等級 | 範圍 |
|---|---|
| **A 唯讀** | `snmpget`/`snmpwalk`/`snmpgetnext`、`tcpdump`、`cat`、`ps`、`fw_printenv`、讀 log |
| **B 改狀態** | 改 `/etc/moxa/netsnmp/agentx_owned.list`、重啟 snmpd、`snmpset`、`moxash` 改設定 |
| **C 韌體** | `fwr_change.sh` 切 partition、`swupdate` 燒 `.swu` 驗證 Plan E 改動 |

**Why:** 這個 session 幾乎每一步驗證都要使用者手動貼指令、再把輸出貼回來,來回十幾輪。
使用者主動提議讓我直接操作以加快驗證。

**How to apply:**
- 執行前**講明是哪一級**,讓使用者看得到即將發生什麼(這是授權的交換條件,不是可省略的客套)。
- **C 級不放寬 [[project-dut-dual-image-ab-pair]] 的護欄**:`--protect 2` 與
  `--control-build 2026_0805_2335` 維持開啟,燒錄一律**從 mainline 對照組那側**跑。
  要用 `--protect none` / `--control-build none` 得另外問。
- 未列出的(重新分割儲存、改帳密、factory reset、操作其他裝置)一律不在授權內。
- **優先走網路而非序列 console**:SNMP 查詢直接從開發主機打即可
  (**要用 `/usr/bin/snmpwalk`;`~/.local/bin/snmpwalk` 是 pysnmp 版會卡住**);
  需要登進 DUT 時用 ssh(22 埠、admin/moxa、`expect` 已裝),比序列快又乾淨,
  而且不必請使用者關掉 minicom。序列只當備援 —— 它慢,而且 kernel log 會插進輸出把行切斷。

相關:[[project-dut-dual-image-ab-pair]]
