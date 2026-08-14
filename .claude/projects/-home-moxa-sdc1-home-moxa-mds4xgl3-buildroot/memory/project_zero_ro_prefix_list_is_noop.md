---
name: project_zero_ro_prefix_list_is_noop
description: "全 RW(0 個 RO)的前綴列進 agentx_owned.list 是 no-op;唯一有意義的旗標是 +getfwd,+nodelegate 在 RO=0 時多餘;且 +getfwd 也不會讓未註冊的 index 欄出現"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdcc4d2c-9721-438a-afe2-8482c5b0ae9b
  modified: 2026-08-13T09:49:06.258Z
---

`agentx_owned.list` 的委派機制(`ies_auto_mibs.c:3062-3065` 註解自述):

> 「At registration time an **RO** entry whose URI matches is **not registered
> locally** at all, so the snmpd master routes it to whichever AgentX subagent
> claimed the OID. **RW entries are always registered locally**, because SET has
> to stay on the framework path.」

→ **前綴若 0 個 RO,單純列入完全沒有作用。** 沒有 entry 會被跳過,
master 的路由一個位元都不變。

實例(2026-08-13 查證):`mxstcldb/` 3 欄、`mxrlpsdb/` 4 欄、`mxlldp/` 6 欄,
**三者全部 `HANDLER_CAN_RWRITE`,對應 setup 檔也沒有任何 `entry->mode` 賦值** ——
連 mxQos 那種「被覆寫成 RONLY 的一欄」都沒有。

## 由此推出的三條

1. **有意義的旗標只有 `+getfwd`**(把 RW 欄的 GET 轉給子代理)。
   `+nodelegate` 的語意是「轉發但不委派 RO」,RO=0 時它**多餘**。
2. **`+getfwd` 也不會讓「in-master 未註冊的 index 欄」出現。**
   它只改 GET 的去向,不改註冊表,所以 GETNEXT/walk 的骨架不變。
3. **「ISS 的 *db.h 有這一欄」不等於「委派後就會冒出來」。** 兩件事之間隔著
   「有沒有 RO entry 可跳過」這一步。

## Why

2026-08-13 我對 `mxstcldb/`/`mxrlpsdb/` 預測「委派後各 +1 個 index 欄」,
被 `snmp-plan-E reopen 7` 用這條機制推翻。**我自己的盤點輸出就印著 `mode: {'RW': N}`,
使用者原始訊息第一句也寫了「全是 RW」** —— 資料在手上,推論仍然跳步。
教訓:從「ISS 有涵蓋」到「委派會生效」之間,務必補上 RO 計數這一格。

## 未註冊的 index 欄怎麼才會出現

不是靠 list,是靠 **ISS 註冊整個 root 區段**([[project_iss_agentx_registration_scope]])。
in-master 註冊的是欄層 OID(較長),ISS 是 root(較短);in-master 沒註冊的
`~.1.1.1.1` 只有 ISS 的區段覆蓋得到 → **在有 ISS 子代理的 image 上本來就該被服務,
不需要改 list**。優先權不衝突,因為那個 OID 本地根本沒登記
(注意方向:[[project_agentx_priority_direction_inverted]] 小的贏,但只在雙方都註冊時才適用)。

→ **所以驗證順序應該是:先在 Plan E 上唯讀 walk 一次跟 mainline 比,
再談要不要動 list。** 這一步成本是三個 walk。

相關:[[project_agentx_owned_two_axis_design]]、[[project_iss_coverage_screen_before_delegating]]、
[[feedback_simple_time_snmpwalk_for_surveys]]
