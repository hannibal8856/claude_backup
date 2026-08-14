---
name: project_migration_verification_folder
description: "每個 MIB group 的搬遷驗證與效能比較放 ~/WORK/SNMP_50ms/snmp-plan-E_reopen/,一組一份"
metadata: 
  node_type: memory
  type: project
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T07:15:19.510Z
---

使用者 2026-08-13 指定的慣例。

```
~/WORK/SNMP_50ms/snmp-plan-E_reopen/
    README.md                                    ← 慣例與最低要求
    <mibgroup>-manual-test-summary-<YYYY-MM-DD>.md
```

**一組一份**;同一組重測**另開新檔換日期,不覆蓋** —— 舊結論被推翻時要能看出
當初依據什麼下判斷。新檔開頭註明取代哪一份。

一份文件至少要回答:會不會轉發(**pcap 證實**,不是「回得到值」)、完整性
(逐表比欄位,**比 OID 不比名字**)、效能(**交錯 A/B/A** + 中位數 + 重複性)、
搬/不搬與理由(**「不搬」是合格的結論**)、證據路徑、以及踩到的量測陷阱。

第一份是 `mxqos-manual-test-summary-2026-08-13.md`(結論:不搬,轉發慢 14.0%),
它的**第 8 節是量測陷阱清單**,動手前該讀 —— 之後每一份都應該把新踩到的坑補進去。

⚠️ 這個資料夾與 handoff 不同:**handoff 一律不進版控**,但這裡是長期資產。
是否進版控使用者未指示,要問。

相關:[[feedback_verify_completeness_and_perf]]、[[feedback_absence_claims_need_reach_proof]]、
[[project_mxqos_forwarding_measured_slower]]
