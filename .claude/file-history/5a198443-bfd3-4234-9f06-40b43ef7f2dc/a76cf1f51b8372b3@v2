---
name: check-mib-max-access-before-judging-behaviour
description: 判定 in-master SNMP 行為是缺陷還是設計前，先查 snmp_moxa_mib/private/*.mib 的 MAX-ACCESS
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5a198443-bfd3-4234-9f06-40b43ef7f2dc
  modified: 2026-08-05T11:48:55.402Z
---

要說某個 OID「walk 不到是缺陷」之前，先去 `dl/snmp_moxa_mib/private/<mib>.mib` 看那個
object 的 `MAX-ACCESS`。`not-accessible` 與 `accessible-for-notify` 依 SMI 都**不得**
由 GET / GETNEXT 回傳，table 的 INDEX 欄常常就是這兩種。

**Why:** 2026-08-05 查 mx_device_io 時，我從 C 原始碼把 `entry_handle_exception()` 的
`<= 0` 追出來，判定「index 欄 walk 不到是 off-by-one 缺陷」。使用者反問「.mib 的設計和
ies-auto-mibs 的行為不一樣嗎」，一查 `mxDeviceIo.mib` 才發現四個 index 欄全是
not-accessible / accessible-for-notify —— walk 不到才是對的，反而是 `snmpget` 拿得到值
那一邊違反 MIB（`net_mx_device_io.h` 把 8 個 entry 全宣告 `HANDLER_CAN_RONLY`）。
只讀實作原始碼會把結論做反。

**How to apply:** 遇到「某 OID 出現/不出現在 walk」的問題，MIB 檔是第一手依據，
ies-auto-mibs 的 `.h`（`.mode` 欄位）只是實作，兩者不一致時以 MIB 為準並把差異記下來。
enum 值也一樣可以拿 MIB 交叉驗證 generate_uri_snmp_table 的映射。
見 [[snmp-work-notes-repo]]、[[snmpwalk-diff-confounded-by-dut-config]]。
