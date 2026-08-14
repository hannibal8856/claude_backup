---
name: feedback-dut-snmp-restart-and-mount-traps
description: "重啟 DUT snmpd 要走 moxash 且 acc en 有 [y/N] 互動;產檔與 mount 絕不可寫成同一條指令"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-12T09:51:49.780Z
---

2026-08-12 由 `snmp-plan-E reopen 6` 實地踩到並回報(其 user 指正),兩個都會把 DUT 留在壞狀態。

## ① 重啟 snmpd 走 moxash,而 `acc en` 有互動確認

支援的路徑是 moxash:`con t` → `snmp-ser acc dis` → `snmp-ser acc en`。

⚠️ **`snmp-ser acc en` 有 `[y/N]` 確認提示,而 `moxash` 需要 tty。**
用 `printf ... | moxash` 餵指令的話,它會**執行完 `dis`(服務停掉)然後卡在確認提示** ——
結果 SNMP 被留在**停用**狀態,要人手動答 `y` 才恢復。

**How to apply:** 不要用管線餵 moxash 做這組操作。要嘛用 `expect` 之類能應答 `y` 的方式,
要嘛拆成兩次、確認 `dis` 完成後再單獨下 `en` 並確實回答提示。
下之前先想好「如果卡住,SNMP 會停在哪個狀態」。

## ② 「產檔」與「mount」絕不可寫成同一條指令

實例:一條指令裡先用 `>` 重導向產生新的 `agentx_owned.list`、再 `mount --bind` 上去。
**重導向被 console 包裝吃掉導致產出空檔,但 `mount` 照樣執行** ——
一個**空的** `agentx_owned.list` 被掛到正式路徑上。

當下因為 snmpd 沒重啟所以沒出事,但**只要有任何東西重啟它,所有委派會全部消失**
(空清單 = `gAgentXOwnedCount` 0 = 沒有前綴命中 = 全部退回 in-master)。

**How to apply:** 分兩步:先產檔、**驗內容**(`wc -l` + `cat`),確認無誤才 mount。
這跟 [[project_rtk_hook_truncates_grep_redirect]] 是同一個形狀 ——
**重導向產出的檔案要對帳行數,不能假設它成功了**。
相關:[[feedback_dut_operation_authorization]]、[[project_agentx_owned_list_parser_landmine]]
