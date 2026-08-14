---
name: project_iss_agentx_two_registrations_getnextindex
description: "ISS 有兩段互不相干的註冊;SNMPRegisterMibWithLock 只登記行程內 MIB DB,不跟 snmpd 說話,GetNextIndex 有在用"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac72d867-b88f-4f5f-9331-a1243ef368f8
  modified: 2026-08-12T08:47:11.236Z
---

常見誤解:因為 `ifmibwr.c:11` 有
`SNMPRegisterMibWithLock(&ifmibOID, &ifmibEntry, CfaLock, CfaUnlock, SNMP_MSR_TGR_TRUE)`,
所以 GETNEXT 之後由 net-snmp 處理、`(*GetNextIndex)()` 形同無用。**不成立。**

**兩段註冊是分開的:**
- `SNMPRegisterMibWithLock()`(真正實作在 `snmpv3/snmpmbdb.c:485`)→ 只登記 Get/GetNextIndex/Set/Test
  函式指標表到 **ISS 行程內部的 MIB DB**,整支函式沒有任何 `netsnmp_*` 呼叫。
  (`code/future/util/snmp/snmputil.c:2322` 的同名函式是全 `UNUSED_PARAM` 的 stub,別看錯。)
- `SnxMainRegisterMibs()`(`snxmain.c:869`)→ 才是送 AgentX Register PDU 給 snmpd master。

**ISS 自己實作整套 AgentX 協定**(`snxmain.c`:`SNX_GETNEXT_PDU`、`SNX_GETBULK_PDU`、
`SnxMainProcessMgmtPdu()`、`pSearchRngLst`),不是用 net-snmp 的 subagent library。
SearchRange 就是 GETNEXT,subagent 必須自己算範圍內的下一個 OID。

`GetNextIndex` 實際呼叫點:`snmpv3/snmplock.c:119`(`SNMPAccessGetNext()`),上游是
`snmpdb.c` 的 `SNMPGetNextOID()`(`:532/:540/:649/:671`)與 `SNMPGetNextReadWriteOID()`
(`:967/:1069/:1091`)。`:649`/`:671` 還用 `pCur->GetNextIndex == pNext->GetNextIndex`
判斷兩欄是否同屬一張表 —— 函式指標被當成「表的身分」在用。

`SNMP_MSR_TGR_TRUE` 是 MIB Save/Restore 的旗標(`snmpmbdb.c:347`),**與 GET/GETNEXT 分派無關**。

**Why:** 這個誤解會把「首欄從連續 walk 消失」的調查引向 ISS 內部。既然 ISS 拿到 SearchRange
一定會照自己的表回答,問題只能出在 **master 如何切分與組合 SearchRange** ——
可據此**排除「ISS 側有 bug」**,把 ADR-0011 / ADR-0017 的調查面縮小到 master 一邊。

## 補充 2026-08-12:兩段註冊「互不相干」要修正 —— 前者是後者的資料來源

`SNMPRegisterMibWithLock()` 確實不呼叫任何 `netsnmp_*`,但它**填的 `gpMibReg` 正是
`SnxMainRegisterMibs()` 走訪的那份清單**(`snxmain.c:872` `tMibReg *pMibPtr = gpMibReg;`)。
所以 `RegisterMXQOS()` 這類函式**最終確實會導致一次 AgentX 註冊**,只是隔了一層、
而且發生在 `snxmain.c:509` 呼叫 `SnxMainRegisterMibs()` 的時間點,不是在 Register 函式裡。

「兩段互不相干」這個講法會讓人以為 `RegisterMXQOS()` 跟 AgentX 無關 —— **不對**,
正確的講法是「**登記與註冊分離**:前者建表,後者在啟動時一次把表送給 master」。

註冊粒度是 **MIB root 區段**,不是單一 OID,且有單一插槽的去重(`:949-967`)。
細節與由此推出的 probe 用法見 [[project-getfwd-probe-sources-and-silent-value-loss]]。

**How to apply:** 判斷 ISS 服務範圍仍看 `*db.h` 的分支涵蓋(見 [[project_iss_agentx_registration_scope]]),
不是看 `SNMPRegisterMibWithLock` 那一行。以上為原始碼閱讀結論,尚無 runtime 佐證;
要坐實可對 `.1.3.6.1.2.1.2` 做 `/usr/bin/snmpgetnext` 並抓 `:705` pcap,看是否為帶 SearchRange 的 GetNext PDU。
