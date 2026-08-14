---
name: snmp-work-notes-repo
description: SNMP 加速專案的設計文件與 snmpwalk 基線放在 ~/WORK/SNMP_50ms（獨立 git repo），不在 buildroot 內
metadata: 
  node_type: memory
  type: reference
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-03T03:06:49.279Z
---

SNMP GET 加速專案（Plan C/D/E）的設計文件、量測資料與 snmpwalk 基線都在
`~/WORK/SNMP_50ms/`，那是一個獨立的 git repo（remote `git@github.com:hannibal8856/SNMP_50ms.git`，
工作分支 `develop`，另有 `main`/`master`）。從 buildroot 工作區看不到它。

- 設計文件命名慣例：`plan-<x>-<topic>-design-YYYY-MM-DD.md`
- snmpwalk 基線在 `snmpwalk/` 子目錄，檔名 `snmpwalk-<版本>-<日期時間>-<OID 子樹>.txt`；
  對照組是 `NOS7`（NOS mainline），實驗組是 `agentx_owned.list` / `plan-D` 等。
  依 `1.3.6.1.2`（標準 MIB）與 `1.3.6.1.4`（Moxa 私有）分檔。
- Confluence 匯出的 `SNMP Enhancement 2026*.pdf` 是專案總覽，內含 Plan C/D/E 的定位。

該目錄下有部分舊文件是由較舊模型產出的，使用者明確表示不希望其內文污染新設計；
引用前先確認，勿逕自當作依據。相關的 code 邊界規範見全域 CLAUDE.md 的
「Inherited Code Boundary (AgentX Restart)」。
