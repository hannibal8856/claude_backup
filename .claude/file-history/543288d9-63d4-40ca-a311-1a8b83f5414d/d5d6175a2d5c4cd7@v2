---
name: project_every_get_pays_shm_attach
description: "出貨 image 每個成功 SNMP GET 都做一次 ftok+shmget+shmat,自 2022 年既有,mainline 也在付"
metadata: 
  node_type: memory
  type: project
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T07:32:10.773Z
---

2026-08-13 追查 mxQos 具象化成本時查到,**與 mxQos 無關,影響整個 SNMP 讀取路徑**。

```
ies_auto_mibs.c:241  util_timeDiff()  → LibUtil_DbgTrace(...)   無旗標前置檢查,無條件呼叫
util_debug.c:81      LibUtil_DbgTrace → if (LibUtil_CheckDbgFlgBits(aType))
util_debug.c:231     LibUtil_CheckDbgFlgBits → ftok(:251) shmget(:260) shmat(:269) shmdt(:281)
                                               每次呼叫,無快取
ies_auto_mibs.c:3772 util_timeDiff("mib_get_success")   ← 每個成功 GET 都走到
ies_auto_mibs.c:2349 util_timeDiff("get_val_from_iss")  ← 每次具象化再一次
```

旗標檢查在 `LibUtil_DbgTrace()` **內部**,呼叫端跳不掉;而 `util_timeDiff` 連一個 `if` 都沒有。
**所以 debug 旗標關著也照付。**

`git blame` 三行都指向 **`280b1b7f`(2022-06-02,"Upgrade to net-snmp 5.8")**,
在 `develop` / `NOS_v6.0_develop` 上 —— **不是 Plan E,是產品既有,mainline 同樣在付。**

⚠️ **量級未測,是候選不是發現。** 但位置很糟:每個 GET、純為診斷而存在。

## 成本落在哪(2026-08-13 `trace 3` 覆核後修正)

**不要去 `_LibUtil_InitDbgFlagShm()` 找。** 它在 `util_debug.c:389-392` 用
`stat(LIB_UTIL_DBG_CTRL_FILE)` 成功就 early-return,穩態下只有一次 `stat`。
**每次呼叫的真正成本在 `LibUtil_CheckDbgFlgBits()` 自己**:`ftok` + `shmget` + `shmat`
+ `shmdt`(原記錄漏了 `shmdt`)。要摘成本改這裡,不是改 Init。

**每次開機的第一次呼叫另外貴一截**:`LIB_UTIL_DBG_CTRL_FILE` = `/run/util_debug/debug_ctrl_block`,
`/run` 是 tmpfs、重開機清空 → 走 Init 的慢路徑,裡面有**兩次 `LibUtil_ExecShCmd`
= 兩次 fork+exec `/bin/sh`**(`mkdir -p` :395、`echo >` :403)。每次開機一次,不是每次請求。

✅ **已查證並排除的一個更糟假設**:曾懷疑「出貨狀態下 SHM 段不存在 → `shmget` 失敗 →
走 `_LibUtil_Dbg2File()`(無條件 `fopen`/`vfprintf`/`fclose`)→ 每個 GET 都寫一行檔」。
**不成立** —— Init 的慢路徑會用 `IPC_CREAT|IPC_EXCL` 建段(`util_debug.c:423-424`),
穩態下 `shmget` 是成功的。**不要再重推這條。**

## 兩個連帶修正

1. 「用 debug image 量 `get_val_from_iss` 會被 instrumentation 汙染」**是錯的** ——
   SHM 成本本來就在付,開旗標只新增每行 trace 的寫出成本
   (`util_debug.c:87-93` 每行一次 `fopen`/`fprintf`/`fclose`)。
2. 這與 [[project_agentx_priority_direction_inverted]] 之類的無關;它是**純粹的固定開銷**,
   不影響正確性。

相關:[[project_mxqos_forwarding_measured_slower]](in-master 單價 2.98 ms/varbind,
這筆成本含在裡面)、[[project_frameworkuri_reconnects_per_request]]
