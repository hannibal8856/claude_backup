---
name: project_snmpd_restart_clears_trace_flag
description: "重啟 snmpd 會清掉 kDbgFlgIssUriSNMP 旗標,註冊期 trace 還寫得出來、之後就全空 — 看起來像「機制沒作用」;重啟後必須重新 moxa_snmp_tools --enable"
metadata: 
  node_type: memory
  type: project
  originSessionId: 866e21a4-9a43-4cf9-8e46-6d4b75d0b7f7
  modified: 2026-08-12T19:32:07.263Z
---

**每次重啟 snmpd 之後,都要重新 `moxa_snmp_tools --enable`。**

症狀非常有欺騙性:**註冊期的 trace(`T1 NOTE` 等)寫得出來,之後的執行期 trace 全空**
——因為註冊發生在啟動最前面,旗標是稍後才被清掉的。所以日誌看起來「有東西、只是沒有
你要找的那些」,而不是明顯的「trace 沒開」。

**Why:** 2026-08-12 我因此得到一個**完全錯誤的結論** —— 宣稱「把 `mxqosdb/` 加進
`agentx_owned.list` 之後 GET 就不再進 handler」,並開始查一個不存在的機制問題。
真正的差別只是:那次測試在重啟**之前** enable,對照組在重啟**之後** enable。
拆穿它的方法是對一個**沒有列入 list** 的前綴下 GET —— 它也一樣沒有 trace,
於是「跟 list 有關」的假設當場破掉。

**How to apply:**

1. 重啟 snmpd(moxash `con t` → `snmp-ser acc dis` → `snmp-ser acc en`)之後,
   **第一件事**就是 `moxa_snmp_tools --enable`,再清 `/run/util_debug/debug_log_5`。
2. 看到「什麼都沒發生」時,**先用一個已知會留下 trace 的對照請求驗證 trace 本身還活著**,
   再去解讀「沒發生」這件事。空日誌與機制無效在輸出上長得一樣。
3. ⚠️ `moxash` 需要 tty(管道餵不進去),而且 `snmp-ser acc en` 有 `[y/N]` 確認 ——
   非互動管道會執行完 `dis`(**服務因此停掉**)就卡在確認提示。
   可用腳本見 [[feedback_dut_operation_authorization]] 提到的 session 產物。

相關:[[project_who_serves_this_prefix_runtime_readouts]]、ADR-0031。
