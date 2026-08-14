---
name: source-comments-in-english
description: 進入原始碼的註解一律用英文；計畫文件、commit message、報告可用中文
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-03T09:46:31.814Z
---

**寫進 `.c` / `.h` / 任何原始碼的註解一律用英文。**
計畫文件、設計文件、commit message、給使用者的報告可以用中文。

**Why:** 使用者在 Plan E Task 3 看到我寫的 `mox_snmp_forward_get_to_subagent()`
帶著整段中文註解進了 `ies_auto_mibs.c`，明確要求「程式內的註解請幫我用英文」。
這個 codebase 的既有註解都是英文，中文註解會破壞一致性，也可能造成編碼問題。

**How to apply:** 寫實作計畫時就要注意——計畫裡的 code block 會被實作者逐字抄進原始碼，
所以 **code block 內的註解必須先寫成英文**，不能等到 review 才發現。
計畫的 Global Constraints 應明列此規則，讓 subagent 也受約束。

相關：[[snmp-work-notes-repo]]、[[self-adjudicate-minor-review-findings]]
