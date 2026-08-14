---
name: self-adjudicate-minor-review-findings
description: SDD 執行時，低風險的 review 發現自行裁決並記進 ledger，不要打斷使用者
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-03T09:14:49.828Z
---

在 subagent-driven-development 流程中，code review 挑出的發現若屬於**工具健壯性、
風格、理論風險**這類低風險等級，**自行判斷並把裁決理由記進 ledger 即可，不要停下來問**。
即使該發現源自計畫本身（流程預設要人工裁決），也照此辦理。

需要停下來問的是：影響架構決策、可能造成回歸、或牽涉產品面（哪些 OID 該對外曝露之類）
的發現。

**Why:** 使用者在 Plan E 的 Task 1 被問了兩個 Python 文字解析的小問題（空白比對寬容度、
續行處理），明確表示看不懂為何需要他裁決，並說「照你說的做」、
「後面就不會再為這種等級的事打斷你了」。判斷成本應由我承擔，不是轉嫁給他。

**How to apply:** 裁決時把「為什麼這樣判」寫進 ledger 而非只寫結論，讓他事後能查、
能推翻。提出問題前先自問：這個決定錯了會怎樣？如果答案是「工具多報一次假差異」，
就自己決定；如果是「送出帶回歸的韌體」或「改變架構」，才問。

相關：[[snmp-work-notes-repo]]
