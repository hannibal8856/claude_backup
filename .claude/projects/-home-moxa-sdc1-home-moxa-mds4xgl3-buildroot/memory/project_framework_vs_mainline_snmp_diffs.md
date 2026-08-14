---
name: framework-vs-mainline-snmp-diffs
description: snmp-plan-E branch 的 framework subagent 與 NOS v7.0 mainline 的已知 SNMP 行為差異(mxTurboRingV2 實測三處)
metadata: 
  node_type: memory
  type: project
  originSessionId: 719f12f0-d8aa-4d12-9ac6-a5bd544bb57c
  modified: 2026-08-08T05:58:42.336Z
---

`snmp-plan-E` branch(framework AgentX subagent 服務 mxTurboRingV2)與 **NOS v7.0 mainline**(in-master 服務)的 `snmpwalk .1.3.6.1.4.1.8691.603.3.4` 實測差異,2026-07-29:**我們 25 個 OID、mainline 23 個**。

| # | OID | 我們 | mainline | 依 MIB 誰正確 |
|---|---|---|---|---|
| 1a | `.1.2.1.1.x` config ring index | `1`,`2` | 無 | **我們對** |
| 1b | `.2.1.1.1.x` stat ring index | `1`,`2` | 無 | **我們對** |
| 2 | `.1.2.1.4.x` ring interface | ~~無~~ → **`01 02`,`03 04`** | `01 02`,`03 04` | ✅ **已修並驗證(2026-08-08)** |
| 3 | `.1.3.3.0` coupling port | ~~`4`~~ → **`5`** | `5` | ✅ **已修並驗證(2026-07-30)** |

**2026-08-08 於 `2026_0808_0844` vs mainline `2026_0805_2335` 全樹重驗(逐值比對):**
planE **27** OID / mainline **23** OID;**mainline 的 OID 一個都沒少**,且 23 個共有 OID
的值**逐位元組完全相同**。planE 多的 4 個就是 #1 的兩組 index 欄
(`.1.2.1.1.{1,2}`、`.2.1.1.1.{1,2}`)。**mxTurboRingV2 至此與 mainline 完全一致或更好,無待修項。**

⚠️ **舊 handoff 裡「T3 未生效,`.603.3.4.1.2.1.4.{1,2}` 回 noSuchInstance」已過時** ——
那是舊 build 的狀態,`0808_0844` 上兩個 OID 都正常回 `Hex-STRING: 01 02` / `03 04`,
與 mainline 一致。不要再照那條去查「C 側 map 沒產生 / Rust handler 讀 config 失敗」。

**權威來源 = `buildroot/dl/snmp_moxa_mib/private/mxTrv2.mib`**(不是 `snmp_moxa_mibs`,目錄是單數 `snmp_moxa_mib`)。

**#1 index 欄 —— 我們是對的,mainline 不符 MIB**:
`trv2ConfigRingTableEntryIndex` 與 `trv2StatRingTableEntryIndex` 的 **MAX-ACCESS 都是 `read-only`**,依 MIB **應該**能被 walk 到。同一份 MIB 裡 `trv2StatDynamicRingCouplingTableEntryGroupIndex` 才是 `not-accessible` —— 證明它有明確區分,不是「INDEX 欄一律 not-accessible」。
mainline 的 `generate_mxTr2_configPortTable()` 明明有寫出 `## tableEntryIndex` 的值,walk 卻不回,**原因未明(mainline 側的缺失)**。framework 這邊由 `mapping_reuse.c::is_turboring_ring()` 納入 `uri_index=="index"` 而正確回出。

**#2 interface(REDUNDANT_PORT)**:framework 未實作,mapping 註解本就標 deferred。2026-07-29 修 `is_index_table()`(排除 named-key ring)讓 deferred 真正生效。**修正前那 16 個 `.1.2.1.4.1~16` 路徑被組成 `"turboringv20/interface"`、全是 noSuchInstance,從未有正確值** → 非 regression。mainline 編碼:`port_index+1`(iftype 為 PORT_CHANNEL 再 `+MAX_PORT_NUM`),兩埠 `"%02x%02x"` 成 2-byte OCTET STRING。

**#3(已修)—— flag 語意未搬移**:in-master `ies_auto_mibs.c` 對帶 `IES_FLAG_SNMP_URI_INTERFACE` 的 entry 做 **GET `+1`(:2498)/ SET `-1`(:2794)**(0-based config port ↔ 1-based SNMP interface)。framework 原本直接回 config 原值,少 1。
**根因:`struct ies_map_entry` 沒有 flags 欄位** —— in-master 的 flag 原本只有 `is_status` 被搬到 framework(`emit_row()`)。
**修法(2026-07-30)**:新增 `is_iface` 欄位(C struct + `emit_row` + Rust `CIesMapEntry`/`MapEntry` + `handle_get` +1 / `handle_set` -1)。
**設計決定:不搬整份 `flags`** —— 它是 bit array(`IES_FLAG_BITS_CHK` 以 `[n/8]` 索引),且 20+ flag 中 framework 只實作 1 個語意;改採**逐語意提取成獨立欄位**,與既有 `is_status` 同風格。日後要用新 flag 語意,就再挖一個欄位。
`REPLACE_TRUTH_VALUE` 的效果剛好被 handler 的 bool→1/2 涵蓋,屬巧合而非設計。

**Why:** 「與 mainline 不同」≠「我們錯」。實際三處中有一處是 mainline 不符 MIB。#3 是**一類**問題 —— 任何帶 `IES_FLAG_SNMP_URI_INTERFACE` 的 OID 都會少 1,需清查還有哪些 group 用到該 flag。

**⚠️ 最重要的教訓:先查 MIB,不要靠 walk 實驗猜。**
`snmp_moxa_mib/private/*.mib` 是 SNMP 側的**權威定義**(MAX-ACCESS 決定該不該出現在 walk、SYNTAX 決定型別與編碼、INDEX 子句決定 table 結構),而 `3rdparty_net_snmp/ies-auto-mibs/net_mx_*.h` 是 URI 側的映射(uri / uri_index / flags)。**framework 的 ies_map 只用了後者,完全沒有參照 MIB** —— 所以「index 欄該不該回」「designatedMaster 要 6-byte」「turboRing 是 named-key 還是陣列」全靠實驗反覆試,2026-07-29 為此繞了很多路。`.h` 的 `mode` 只有 RONLY/RWRITE,**沒有 not-accessible 的概念**,這正是 MIB 能補上的缺口。

**How to apply:** 遇到 framework vs mainline 的 SNMP 行為差異,**第一步是開 `snmp_moxa_mib/private/<group>.mib` 查該 OID 的 MAX-ACCESS 與 SYNTAX**,再判斷誰對。收斂順序:#3 優先(值是錯的,在 `ies_map_entry` 補 flags 欄位並實作 `URI_INTERFACE` 的 +1);#2 實作 REDUNDANT_PORT(MIB: OCTET STRING、read-write、兩 octet 分別為 primary/secondary interface);#1 我們已正確,不需改。相關:[[project_snmp_walk_slow_diagnosis]]、[[project_mxipif_col2_inmaster_deferred]]、[[project_snmp_framework_subagent_migration]]。
