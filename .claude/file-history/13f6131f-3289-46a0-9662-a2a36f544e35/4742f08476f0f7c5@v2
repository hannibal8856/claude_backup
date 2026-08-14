---
name: reference-moxa-cli-manuals
description: DUT 的 CLI 參考手冊(兩份 PDF)+ 用 moxash 設定功能的授權;可用來把空表填出資料再做 SNMP 驗證
metadata: 
  node_type: memory
  type: reference
  originSessionId: 13f6131f-3289-46a0-9662-a2a36f544e35
  modified: 2026-08-06T10:20:00.582Z
---

`/home/moxa/WORK/SNMP_50ms/` 底下兩份 CLI 手冊,查 `moxash` 指令用:

- `moxa-next-generation-os-cli-manual-v1.0.pdf`(204 頁)—— 主要手冊
- `moxa-layer-3-managed-switch-next-generation-os-command-line-interface-v1.0.pdf`(57 頁)—— L3 專屬

**設定方式**:ssh 進 DUT(admin/moxa)→ `su`(同密碼)→ `moxash` → `configure terminal`。
有些功能設定完可以立即驗證,不必重開機。

**Why 這對 SNMP 遷移工作重要**:`agentx_owned.list` 委派的驗證靠 before/after walk 比對筆數,
**空表沒有鑑別力**。iss1 待搬清單裡「零 RW、形狀最安全」那一類(`stdcipdb/`、`mxdhcpsnpdb/`、
`mxmacsecdb/`、`mxtrackingdb/`、`mxunicastroutingtabledb/`)先前被我以「功能預設沒開、表是空的」
為由排除 —— 有了 CLI 就可以**先用 moxash 把功能開起來、把表填出資料,再做委派測試**,
那批候選就重新可用了。

**How to apply**:要查指令先讀 PDF(用 Read 的 pages 參數,單次上限 20 頁),
不要憑印象下指令。改設定屬 [[feedback-dut-operation-authorization]] 的 B 級,執行前講明等級。

相關:[[project-dut-dual-image-ab-pair]]、[[project-iss-agentx-registration-scope]]
