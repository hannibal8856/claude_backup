---
name: project_moxa_snmp_tools_coverage_shrinks
description: "moxa_snmp_tools --dump 只看得到還留在 in-master 的請求;已委派的 OID 會 dump 出空的,跟「沒發生」長得一樣"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac72d867-b88f-4f5f-9331-a1243ef368f8
  modified: 2026-08-11T10:12:04.818Z
---

`moxa_snmp_tools` 只是 `kDbgFlgIssUriSNMP` 這個 debug flag 的薄殼(`--enable` 設 bit、
`--dump` cat `/run/util_debug/debug_log_<flag>`)。AgentX 的導入沒動到它,四步流程照常可用,
但**它的涵蓋範圍已經隨委派靜默縮小**。

會寫進那個 log 的只有 snmpd 行程內的 in-master 路徑:`ies-auto-mibs/*.c`、
`app_moxa_iss_10_1_0/code/uri_ctrl_hook/src/*`(被 `mox_snmp_iss_uri_read_inplace` dlopen)、
`code/future/urihook/src/urimain.c`、以及 Moxa patch 過的 net-snmp `snmptrap.c`/`snmpusm.c`/`snmpv3.c`。

**不會**寫進去:ISS 的 SNMP agent 核心(`code/future/snmpv3/`,用自己的 `SNMPTrace()`/`UtlTrcLog()`)、
framework subagent(Rust)、`lib_moxa_ies_auto_mibs`。

**Why:** 已委派的 OID(`ifmibdb/`、`stdethdb/`、`mxportdb/` 的 RO 欄、`mxrstpdb/` …)
做 SNMP 請求時 dump 會是空的,而那**看起來跟「請求根本沒發生」一模一樣** —— 會把人導向錯誤的結論
(以為請求沒送到、以為工具壞了)。

**How to apply:** 用 `--dump` 之前先確認該 OID 還在不在 in-master:查 `agentx_owned.list` 的前綴
+ 該 entry 的 `.mode`(RO 委派、RW 留下)。空的 dump **不是**「沒有請求」的證據。要在 wire 上
確認歸屬,還是得抓 `:705` 的 pcap —— 見 [[project_getfwd_probe_must_be_wire_verified]]。
另注意 CLI 那一步能被記錄是推測(`uri_ctrl_hook/src/ies_uri_handle.c` 也用同一 flag),未實跑驗證。
