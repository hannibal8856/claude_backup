---
name: feedback_absence_claims_need_reach_proof
description: "凡是結論形如「X 不存在／沒有發生」,都要另外證明觀測管道走到了 X 該在的位置"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T07:02:41.713Z
---

2026-08-13 一天之內同一形狀出現三次,三次都是我(或工具)沒走到,而不是被測物沒有:

| 觀測 | 我下的結論 | 實際 |
|---|---|---|
| pcap 零個 Get PDU | 「沒有轉發」 | `tcpdump -G` 在 walk 之前就結束,什麼都沒拍到 |
| `snmpwalk` 回 `No Such Object` | 「mainline 沒有 mxQos」 | walk 在第一個請求就中止,`.1.4`–`.1.7` 從未被查詢 |
| 收回臂只回 62 欄(對 73) | 「欄位比較少」 | 疑似逾時讓 walk 提早中止(未定案) |

**Why:** 「錯的數字」還會被下一個人拿去對帳而露出矛盾;**「缺席」不會** ——
沒有任何一行輸出會說「你沒走到那裡」。而缺席又正好是許多假說的預期結果,
所以失敗模式與想要的答案長得一模一樣,看起來像完美的證據。

**How to apply:** 結論的形式若是「X 不存在 / 沒有發生 / 沒有被呼叫」,
**先證明觀測管道抵達了 X 應該在的位置**,再談 X 在不在:

- pcap → 先確認擷取程序在事件發生時活著(`kill -0`),並記錄被觸發事件的規模(varbind 數)
- walk → 先確認 walk 沒有中途中止(檢查 stderr 與 varbind 數),再談某段有沒有資料
- 「沒被呼叫」→ 先用一個已知會留下痕跡的對照請求,確認觀測管道本身還活著
  (見 [[project_snmpd_restart_clears_trace_flag]])
- SNMP 專屬:`badValue` vs `endOfMibView` 才分辨「handler 回錯」與「沒註冊」;
  `snmpwalk` 印的 `No Such Object` 兩種情況都會出現,不可當判準

相關:[[project_measure_snmp_walk_skill_defects]]、[[project_mxqos_getnext_boundary_bug]]、
[[project_getfwd_probe_must_be_wire_verified]]
