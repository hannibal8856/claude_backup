---
name: project_tr2_getnext_subtree_vs_itertable
description: "ADR-0009 的 3.9s 不是「Subtree 勝過 IterTable」的證據 — 它量的是逐 OID register_instance + 16 個壞 OID,而那個根因已被修掉;mxTurboRingV2 改用 IterTable 從未被評估過"
metadata: 
  node_type: memory
  type: project
  originSessionId: ee275acd-d869-43fd-ba9b-5fe897b8db7b
  modified: 2026-08-11T08:31:18.097Z
---

2026-08-11 評估(使用者裁示**延後,等 Plan E 架構穩定後再做**;細節在 task #1)。

**背景**:framework subagent 註冊 4 個群組,只有 mxTurboRingV2 是 `RegKind::Subtree` +
`register_handler`,GETNEXT 由 `snmp_subagent.rs::handle_getnext` **自行實作**;
其餘三個(trustedIpTable / snmpTrapHostTable / l3VlanIfTable)走 `IterTable` →
net-snmp 的 `table_iterator` helper。使用者的原則是 **GETNEXT 都交給 net-snmp**。

**最容易被誤讀的一點,也是這則 memory 存在的理由:**

**ADR-0009 記載的 3.915s → 0.023s(170 倍)不是「Subtree 比 IterTable 好」的證據。**
讀 ADR-0009 很容易得到「所以必須用 Subtree」的結論,那是錯的:

- 真正病因是 `is_index_table()` 把 named-key 的 `{ring1, ring2}` **誤判成陣列 index-table**,
  emit 了 16 個永遠無法解析的 OID(`.603.3.4.1.2.1.4.1~16`);當時又是**逐 OID
  `register_instance`**,master 只能一個一個 probe → 18 次 AgentX round-trip。
- **ADR-0009 一次改了兩件事**:Decision 3 修 mapping、Decision 1+2 改註冊方式。
  **`IterTable` 這個選項從未被量過** —— 它不是被否決,是沒被考慮。
- 而 **Decision 3 已經把根因移除**,後續 `16a9c68` / `e27e5fc` 又把 `interface` 欄正式服務
  起來(T3)。那 16 個壞 OID 現在不存在 → `handle_getnext` 的 in-process 跳過迴圈
  **可能是在防一個已經被修掉的狀況**(未證實,見下)。

**形狀事實**(`net_mx_turboring_v2.h`,29 個 entry):`.603.3.4` 底下是
**3 張表 + 8 個 scalar**,分散在 `.1`(config)/ `.2`(status)/ `.3`(stat)三個分支。
三張表(`.1.2.1` / `.2.1.1` / `.3.3.1`)的 index **都是單一 INTEGER**,符合 IterTable 前提;
scalar 搬不動,要用 `MoxaAgentX_RegisterScalar` / `RegisterInstance`。
所以「對齊其他三個」= **把 1 個註冊拆成 11 個**,不是換個 API 而已。

**未答的問題**(動工前要先解決):執行期到底還有沒有 valueless OID?
狀態表的列數是執行期決定的,若 map emit 固定列數而執行期只有部分存在,跳過迴圈就還需要。
**這正好是 IterTable 的 live `row_count` 能從源頭解決、Subtree 只能事後跳過的東西。**
要在 DUT 上把 `.603.3.4` walk 出的 OID 集合跟 map 的 29 個 entry 比對才知道。

**How to apply:** 之後若有人引用 ADR-0009 主張「framework 必須自行處理 GETNEXT」,
先確認他講的是不是那 16 個壞 OID 的情境 —— 那個情境已經不存在。
真要改,走漸進路線:保留外層 Subtree 當 catch-all,一次只把一張表加成 IterTable 並量一次
(`measure-snmp-walk` 交錯協定,外加**每個 registration 邊界單獨 `snmpgetnext`** ——
ADR-0009 當初就是這樣定位問題的)。相關:[[feedback_verify_completeness_and_perf]]
