---
name: project_iss_coverage_screen_before_delegating
description: "委派候選的唯一可靠篩選是「ISS 有沒有宣告該 OID root」;mod_uri 前綴與 iss_build 都會給假陽性(mxLa 為反例,委派會直接刪掉 OID)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 03565926-6fb8-4a69-a12c-4471723877ba
  modified: 2026-08-07T05:17:08.392Z
---

2026-08-07 查 mxLa(`.1.3.6.1.4.1.8691.603.1.2`)能不能加進 `agentx_owned.list` 時確立。

**唯一可靠的篩選:ISS 有沒有宣告涵蓋該 subtree 的 OID root。** 一次撈完:

```bash
cd ~/mds4xgl3/buildroot/dl/app_moxa_iss_10_1_0/code/future
grep -rhoE 'UINT4 [a-zA-Z0-9_]+ *\[\] *= *\{[0-9, ]*8691[0-9, ]*\}' --include=*.h --include=*.c . | sort -u
```

回 37 個 Moxa 8691 root。`mxPort = .603.1.1` 在;**`.603.1.2` 不在**,全樹也沒有任何
`mxLa*` 檔,`603,1,2` 這個 arc 在 ISS 原始碼出現 0 次。所以 mxLa 是「**不能搬**」不是「沒搬」。
(仍要記得 ADR-0011 的但書:root 只是 SysORTable 標籤,實際涵蓋看 `*db.h` 分支,可能比 root 廣。)

**兩個會騙人的代理指標:**

- **mod_uri 前綴 ≠ ISS 擁有。** in-master 的 mxLa 欄位(`net_mxLadb.h`,11 欄,全是
  `.8691.603.1.2.*`)掛在 `fsladb/` 與 `fscfadb/` 前綴下,但 ISS 自己的
  `la/inc/fsladb.h` 註冊的是 `fsla[] = {1,3,6,1,4,1,2076,63}` —— Future 的
  enterprise OID 2076,完全不同的子樹。**同一個 URI 前綴橫跨兩個不同 owner 的 MIB root。**
- **`iss_build==1` ≠ ISS 服務。** 見 [[project_agentx_owned_two_axis_design]] 的更正。

**後果不是「沒收益」,是「主動回歸」。** 把 `fsladb/` 加進 `agentx_owned.list` →
in-master 跳過註冊 mxLa 的 RO 欄 → master 依 OID 路由 → ISS 在 `.8691.603.1.2` 沒有註冊
→ 那些欄位變成 NoSuchObject,直接消失。

**Why:** doc 記的 `mxladb/` 否決理由是「walk 僅 0.45 秒(ISS 應已在服務)」,pcap 證明
ISS 根本沒在服務(整棵 55 筆 walk 零 AgentX PDU,同一份擷取裡 mxPort/dot3 正對照有 Get-PDU)。
結論對、理由全錯 —— 照那條理由去挑候選會挑到會刪 OID 的目標。

**How to apply:** 35 支候選掃描時,**先用上面那條 grep 對照 ISS root 清單**,再談 walk 耗時。
耗時判準(ADR-0013)只排序「值不值得」,不能判定「能不能」。
相關:[[project_snmp_walk_slow_diagnosis]]、[[project_moduri_correlates_iss_owned]]、
[[project_iss_agentx_registration_scope]]
