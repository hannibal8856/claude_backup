---
name: report-changed-packages
description: 每次交付變更時，主動列出改了哪些 buildroot package 與對應的執行檔
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-03T10:06:33.369Z
---

**每次把變更交給使用者時，主動列出改動了哪些 buildroot package**，不要只講改了哪些檔案。
使用者要據此決定重建與燒錄範圍。

要附上的資訊：

- package 名稱（`make <pkg>-rebuild` 用得到的那個名字）
- 對應的 `dl/<repo>` 與 commit 範圍
- **實際受影響的目標執行檔**（例如改 `ies-auto-mibs` 實際影響的是 `/bin/snmpd`，
  因為它是編進 snmpd 的 MIB module，不是獨立的 binary）

**Why:** 使用者在 Plan E Task 3 完成後明確要求「另外每次請告訴我改了哪些 packages」。
這個 codebase 一個 package 可能對應多個 dl repo，而 dl repo 與最終 binary 的關係並不直觀
（ies-auto-mibs → snmpd 就是例子），只講檔案名他無法判斷要重建什麼。

**How to apply:** 一個 SDD task 完成、或任何一批變更交付時就列。若一個 task 跨多個 repo
（例如 Task 4 同時動 `3rdparty_net_snmp` 與 `plugin_moxa_snmp`），兩個都要列出來。

相關：[[snmp-work-notes-repo]]
