---
name: project_iss_data_source_three_way
description: "搬遷篩選要三分資料來源,iss_build 只分得開兩類;帶 ISS_REMAP_TBL/MERGE 旗標的前綴資料在 Aricent .2076(刻意不 AgentX 註冊)→ 委派/轉發結構上不可能,直接取消資格"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdcc4d2c-9721-438a-afe2-8482c5b0ae9b
  modified: 2026-08-14T02:35:08.292Z
---

## `iss_build` 混淆了兩件不同的事

| # | 資料來源 | 判別 | AgentX 可達 |
|---|---|---|---|
| 1 | ISS 在**同一個 Moxa OID** 上有 AgentX 註冊 | ISS `*db.h` 有該 root **且不在 `.2076`** | ✅ 可委派/轉發 |
| 2 | ISS 有資料但在 **Aricent OID**,靠產生器搬到 Moxa OID | **`IES_FLAG_SNMP_ISS_REMAP_TBL` / `ISS_REMAP_MERGE_TABLE`** | ❌ **結構上不可能** |
| 3 | framework 經 URI(flask) | `iss_build == 0` | ❌(另一條路)|

**`iss_build == 1` 只表示「資料源自 ISS」,不表示「ISS 服務這個 OID」。**
類型 1 和 2 的 `iss_build` 都是 1 —— 這就是盲點。

## 為什麼類型 2 結構上不可能

`snxmain.c:911-919` 明寫:

> `/* Do not AgentX-register enterprises.2076 (SNX_PROP_MIBID_1). NOS7 does not
> expose this ISS proprietary tree (~5k OIDs). */`

類型 2 的資料實際住在 `.1.3.6.1.4.1.2076.*`(Aricent 私有樹),**那棵樹刻意永不 AgentX 註冊**;
搬到 Moxa OID 是靠 `generate_iss_snmp_merge_table` / `generate_iss_remap_table`
(Rust,`snmp_script_rust/`)讀 ISS 的值再改寫 OID,寫成 value file 給 in-master 讀。

→ **目標 Moxa OID 上永遠沒有任何 subagent 應答。** 列進 `agentx_owned.list`
不是「probe 沒指好」,是沒有可轉發的對象 —— 一定掉值。

實例:`mxlldp/portTable/portIdSubtype` 的 entry 寫 `iss_build = 1`、
OID `.8691.603.5.1.1.4.1.1`,但資料在 `.2076.158.2.3.1.1`
(見 `snmp_script_rust/generate_iss_snmp_merge_table/src/main.rs` 的 `TableOid`
`iss_oid` / `mod_oid` 對照)。2026-08-14 對它下 `+getfwd` → **25 varbind 全歸零**。

## 取消資格清單(靜態可查,不必上機、不必 grep ISS)

掃 `ies_auto_mibs_setup_net_*.c` 的 `IES_FLAG_SNMP_ISS_REMAP` 命中:

```
mxlldp/{enable,chassisIdSubtype,chassisId,portTable/}  → .603.5.1.1.{1,2,3,4}
fsvlandb/, fscfadb/{ifSet,ifReset}MgmtVlanList, mxvlan/vlanConfigPortTable/
                                                       → .603.2.3.1.{1,2,3,4}
fscfadb/ifMainTable/, fsladb/{fsLaPortChannelTable,fsLaPortTable}/
                                                       → .603.1.2.*
```

→ **`mxlldp/`、`mxvlan/`、`fsvlandb/`、`fscfadb/`、`fsladb/` 全部取消資格。**

## 與實測完美相關(2026-08-14 mainline 普查)

| 群組 | walk | ISS 涵蓋 grep | REMAP |
|---|---|---|---|
| `.603.5.1` | 缺 1 欄、12 列隱形 | 0 | **全 REMAP** |
| `.603.2.3` | **walk 中止 badValue**、缺 3 欄 | 0 | **全 REMAP** |
| `.603.1.2` | 缺 3 欄、17 列隱形 | 0 | **全 REMAP** |
| `.603.4.4` `.603.4.8` | 完整 | ✓ | 無 |

**三個失敗全是 REMAP,兩個健康的都不是,零例外。**

**How to apply:** 挑搬遷目標的順序 ——
1. **先掃 REMAP 旗標**,有就取消資格,不必再往下查(比 grep ISS `*db.h` 更早、更準,
   而且在我們自己的樹裡)
2. 沒 REMAP 才看 `iss_build`;`1` → 再確認 ISS `*db.h` 同址註冊且不在 `.2076`
3. **`iss_build` 不可單獨使用**

相關:[[project_iss_coverage_screen_before_delegating]]、[[project_zero_ro_prefix_list_is_noop]]、
[[project_getfwd_probe_sources_and_silent_value_loss]]
