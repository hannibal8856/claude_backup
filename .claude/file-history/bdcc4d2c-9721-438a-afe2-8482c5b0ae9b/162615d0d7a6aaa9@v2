---
name: project_iss_table_materialization_single_slot_cache
description: "iss_build==1 的表每次開表都整張具象化到 /moxa/run/auto_mibs(tmpfs);快取只有 1 槽且換表會 unlink,200ms idle TTL,800ms 絕對壽命是 dead code"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdcc4d2c-9721-438a-afe2-8482c5b0ae9b
  modified: 2026-08-13T07:16:53.998Z
---

`iss_build == 1` 的 entry(mxQos 29/29、ifmibdb 47/47 都是)走
`entry_handle_generate_iss_value_file()`,**不是** flask 路徑。分岔只看
`iss_build`(`mox_snmp_handle_entry` 的 `CheckFromUri` = `iss_build == 0`)。

**具象化**:`mox_snmp_iss_uri_read_inplace(uri, fname)` 把**整張表**寫成
`/moxa/run/auto_mibs/<uri 的 / 換成 _>tbl`(scalar 是 `_ent`),再由
`fileBuffer_init()` 整份 parse 進 `gfileBufCtrlBlock`。
`/moxa/run` **是 tmpfs**(使用者確認;dl/ 樹裡查不到宣告,掛載點在 dl 之外
—— 「grep dl/ 沒有」不能當否定證據)。

**所以成本不是 I/O**,是 fork+exec、向 ISS 取 URI 的往返、remap、
`/bin/iss_snmp_makeup_index` 的 fork、以及 parse。換更快的儲存救不了。

## 快取的三個要命性質

1. **深度 = 1 張表**。`gSnmpTblSnapShot` 是單一全域,只存一個 `fname`。
2. **換表不是驅逐,是刪檔**。`util_table_snapshot_reset()` 對前一張表
   `unlink()`。A→B→A 時 A 要從頭再做一次,零重用。
3. **TTL 200ms 且是 idle timer**(`MAX_TABLE_TIMELAST`),`time_lastUpdate`
   每次呼叫都重寫。連續請求(封包實測間隔 0–1ms)永遠命中;人手點下一張表
   必定過期。

⚠️ **`MAX_TABLE_TIMEOUT`(800ms 絕對壽命)是 dead code** ——
`entry_handle_check_value_file` 的 if/else 兩邊都 `return`,底下不可達。
原設計的絕對壽命上限從未生效。

## 對量測的意義

一次 MIB browser table view 付**兩次**具象化:開表時本表,以及尾端 GETNEXT
的最後一個 varbind 掉出最後一欄、跨進**下一張表**時(那張接著就被丟掉)。
封包實測:頭尾 2 個請求佔 table view 總時間 60–71%,中段逐列讀取兩顆 image
完全相同。

→ **連續 walk 與 table view 量到的不是同一件事**,walk 把具象化攤在大量
varbind 上幾乎看不見。兩邊數字不衝突,不可互相推翻。
→ 委派(agentx_owned.list)動不到這條路徑。

**Why:** 2026-08-13 查 mxQos latency 時挖出來。我一開始把尾端慢請求歸因為
「跨界進 `entry_handle_exception()` 本身慢」,被封包否證 —— exception path
不慢,慢的是它觸發的下一張表具象化。

**How to apply:** 看到「第一個請求慢 17 倍、中段都一樣」的形狀,先想單槽快取
而不是 AgentX。要拆首請求成本不必改 code,`ies_auto_mibs.c` 已有
`util_timeDiff("get_val_from_iss", ...)` 包住整段具象化,開 trace 即可。

相關:[[project_frameworkuri_reconnects_per_request]](flask 那條路徑的對應問題)、
[[project_who_serves_this_prefix_runtime_readouts]]、
[[project_measure_snmp_walk_skill_defects]]。
