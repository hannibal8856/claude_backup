---
name: project_mode_override_glob_misses_seventh_file
description: ".mode 覆寫不只 6 個檔 —— glob `ies_auto_mibs_setup*.c` 漏掉 net_stdospfdb_setup.c(3 處=15 個 entry);且一處賦值可以蓋整張表,不是一處一欄"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdcc4d2c-9721-438a-afe2-8482c5b0ae9b
  modified: 2026-08-13T05:00:28.854Z
---

盤點 `entry->mode` 覆寫時有**兩個各自獨立的坑**,踩到任一個靜態 RO 普查就會低估:

**① 檔名 glob 有漏。**
`grep -- "->mode" ies_auto_mibs_setup*.c` 只找得到 6 個檔(ifmibdb 1 / mxQosdb 1 /
stdladb 9 / stdllddb 1 / stdot1db 2 / stdpnadb 4 = 18 處)。
`ies-auto-mibs/` 底下另有一批命名為 `net_*_setup.c` 的檔(`net_stdospfdb_setup.c`、
`net_mxOspfdb_setup.c`、`net_vrrpdb_setup.c`、`net_mx_vlan_setup.c` …約 12 個),
**不在那個 glob 裡**。其中 `net_stdospfdb_setup.c` 有 3 處覆寫。
→ 正確查法:掃 `*.c` 全部,regex `->\s*mode\s*=`
(要排除 `ies_auto_mibs.c:3799` 的 `reqinfo->mode ==` 比較式,以及
`moxa_snmp_handle_util.c:168` 的合成 col 1,那是另一個機制)。

**② 一處賦值 ≠ 一個 entry。**
guard 可能比對 `entry->uri`(整張表)而非 `entry->uri_index`(單一欄)。
`net_stdospfdb_setup.c` 的 3 處就是這種:6 個 scalar + `ospfAuthType` +
`ospfStubAreaTable/` / `ospfAreaRangeTable/` / `ospfHostTable/` 三整表
→ 實際翻轉 **15 個 entry**。
`stdospdb/` 因此是靜態 RO 68 → **實效 83**(ADR-0011 記的「115 筆 59% RO」是靜態值,
實效是 72%)。

那 6 個檔剛好 18 處 = 18 個 entry,但**其中 stdot1db 兩處是整表比對,只是那兩張表
在 in-master 各只有 1 個 entry,巧合對上**。不要把「18 處=18 欄」當成規律。

**Why:** 2026-08-13 覆核前一手的 `.mode` 覆寫模型時抓到。前一手宣稱「靜態普查扣掉
這 6 個檔之後可驗證正確」,`ifmibdb/` 40→41 與實測 probe 41 相符是真的,但那只證明
了 ifmibdb 那一處,推不到全樹。

**How to apply:** 做靜態 RO/RW 普查前,先用全 `*.c` 掃一次覆寫清單,逐處確認 guard
比對的是 `uri` 還是 `uri_index`;是 `uri` 就要去 `net_*.h` 數該表的 RW 欄數。
執行期讀數仍優先 —— 見 [[project_who_serves_this_prefix_runtime_readouts]]。

相關:[[project_agentx_probe_max_128_silent_overflow]](RO 數低估會讓溢出評估失準)。
