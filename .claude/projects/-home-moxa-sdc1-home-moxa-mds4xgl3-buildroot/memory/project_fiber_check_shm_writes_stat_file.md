---
name: project-fiber-check-shm-writes-stat-file
description: "FiberCheckShm_OutputShmInfo 讀 SHM 後還會重寫 fiberCheck.stat,消費端再讀回;deck 的 8ms 宣稱因此未定案"
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-12T01:14:28.244Z
---

`FiberCheckShm_OutputShmInfo()`(`app_moxa_fiber_check/src/fiber_check_shm_api.c:275`)
名副其實會讀 SHM,但 `:310` 接著呼叫 `_OutputStatus()`,`:187` 把整份資料
`fopen("w")` 寫成 `/etc/moxa/app-moxa-fiber-check/fiberCheck.stat`;消費端
`plugin_moxa_fiber_check/framework/src/status.rs:14`(在 `_construct_port_table()` 內)
再用 configparser 讀回來。**所以這條不是純 SHM 路徑,是 SHM → 寫檔 → 讀檔 → parse。**

`status.rs:127-130` 那段 `config.read('...fiberCheck.stat')` 註解**是遺留物,不描述現行行為** ——
Python 原版 `python/status/plugin_status_fiber_check.py:126-129` 就是這兩行連著寫,
Rust 移植時把 `config.read` 挪進 `_construct_port_table` 但註解留在原地。
同理 `fiber_check_shm_api.c:193` 的 `//section for python plugin` 也過時了(消費端已是 Rust)。

**Why:** 交接文件把「函式名 vs 註解不一致」列為 P1 待查,想藉此決定 deck 宣稱的
18–38ms → 8ms 是否仍成立。查完發現名稱與註解都沒有矛盾,但每次 get_status 都付了
1× SHM 讀 + `_ConfigLoad()` + 每 port 一次 `FiberCheck_IsPortLinkUp()` + 整份檔重寫 +
整份讀回 + INI parse 的代價。

**How to apply:** 不要再為了這個函式重讀一次原始碼 —— P1 已結案(2026-08-12,純唯讀分析)。
但 **8ms 這個數字仍未證實**:原始碼看不出當初量測有沒有含那個 write→read→parse round-trip,
只能實測。沿用 [[project_snmp_walk_slow_diagnosis]] 與 measure-snmp-walk 的紀律,
在拿到數字前不要對外引用 8ms。相關陷阱見 [[feedback_verify_completeness_and_perf]]。
