---
name: fiber-check-plan-a-cross-process-bug
description: "fiber_check 的 .stat dumper 跑在 framework process 不是 daemon,所以 daemon 的 process-local 陣列無法傳給它;Plan A 因此讓 rxPower 恆為 N/A"
metadata: 
  node_type: memory
  type: project
  originSessionId: 798535b9-6c18-4db5-bd5d-188d1dd918c0
  modified: 2026-08-03T09:43:02.125Z
---

`FiberCheckShm_OutputShmInfo()`(寫 `/etc/moxa/app-moxa-fiber-check/fiberCheck.stat`)
**不是 fiber_check daemon 呼叫的** —— 是讀取方 on-demand 觸發:`plugin_moxa_fiber_check`
的 `framework/src/status.rs::get_status()` 第一行就呼它,所以實際執行的 process 是
`app_moxa_framework`(DUT 上 pid 1227),不是 daemon(pid 1087)。daemon 的 Makefile 把
`fiber_check_shm_api.o` 直接連進執行檔,**不 map** `libmoxa_fiber_check.so`。

**Why:** 2026-08-03 驗證 Plan A(branch `snmp-plan-E2`,commits `43138ba` / `630a991` /
`d277473`)時,發現它靠 daemon 的 process-local `gIsPortLinkUp[]` 產生 `.stat` 的
`linkStatus.N` 欄位。dumper 那份 copy 永遠是 `{false}`,結果 `fiberCheckStatRxPower`
在 link up + SFP 正常時恆回 "N/A"(其他欄位走 SHM,正常)。這是 production regression,
且沒有 polling dump 週期這回事(`.stat` mtime 隨 snmpget 同秒跳動)。

**How to apply:** 任何要從 daemon 傳資料到 REST/SNMP 讀取路徑的欄位,唯一可行管道是
既有的 `kShmSrvBlkTypeFiberCheckStatusSrv` SHM(`struct FiberCheckStatus`),不是 `.so`
的 global。改那個 struct 不是跨 repo ABI 變更:`fiber_check_monitor.h` 只被
`app_moxa_fiber_check` 自己的三個 `.c` include,ISS 只用 5 個不碰 struct 的 API 函式。
但熱換 binary 不重開機時 `shmget` 會因 size 變大回 EINVAL,測試要重開。
完整記錄見 [[snmp-work-notes-repo]] 指到的 `~/fiber_check_optimization.md` §7。

SNMP 欄位對照(容易踩錯):`.1.3.6.1.4.1.8691.603.5.3.2.1.1.1.<col>.<port>`,
col7=voltage、col8=txPower、**col9=rxPower**、col12/13=txPowerLimit/rxPowerLimit。
