---
name: project_mxport_mainline_baseline_corrected
description: "mxPort 的 NOS 7 mainline walk 基準是 0.768s 不是 0.871s;改善是 −11.3% 不是 −19.8%,8/09 那批未交錯的 mainline 數字整批存疑"
metadata: 
  node_type: memory
  type: project
  originSessionId: ee275acd-d869-43fd-ba9b-5fe897b8db7b
  modified: 2026-08-10T10:15:05.594Z
---

2026-08-10 做了 p2 → p1 → p2 交錯量測(每輪 9 次,PC 端 wall clock,
`/usr/bin/snmpwalk` 走 `.1.3.6.1.4.1.8691.603.1.1`):

| 輪次 | partition | image | vb | median |
|---|---|---|---|---|
| P2a | 2 | `2026_0805_2335` mainline | 154 | 0.774s |
| P1 | 1 | `2026_0810_0021` Plan E | 193 | 0.681s |
| P2b | 2 | mainline | 154 | 0.763s |

mainline 兩輪相差 0.7% → **mainline = 0.768s**。獨立佐證:2026-08-07 的 pcap
(wire 端、不含 client 開銷)是 0.754s。

→ **`~/handoff-snmp-plan-E-2026-08-09.md` 對照表裡的 mxPort mainline 0.871s 是離群值**,
  該表寫的 −19.8% 應為 **−11.3%**。

**這件事的影響範圍比 mxPort 大。** 8/09 那張「對 mainline 的量測結果」整張表
(mxRstp / stdvladb / stdcipdb / ifXTable / stdospdb / ifTable / mxPort / dot3)
**都是同一批、都沒有與 planE 交錯量測** —— ADR-0018 當時就標註過這件事。
**任何要進簡報的 mainline 數字都應該重新交錯量過。**

順帶觀察:三輪各 9 次**都恰好有一次** ~1.2s 的離群(p1 p2 皆然)→ 環境週期性因素,
與 Plan E 無關;所以要用**中位數**不要用平均。

**How to apply:** 引用 mainline 對照數字前先確認它是不是 8/09 那批;是的話重新交錯量。
量測方法見 [[project_snmp_walk_slow_diagnosis]];切 partition 用
`printf 'Y\nY\n' | /moxa/fwr_change.sh`,不具破壞性,可自由來回(每次重開機約 3 分鐘,
量測前等 uptime > 200s 讓服務穩定)。相關:[[project_dut_dual_image_ab_pair]]、
[[project_registration_count_hypothesis_refuted]]
