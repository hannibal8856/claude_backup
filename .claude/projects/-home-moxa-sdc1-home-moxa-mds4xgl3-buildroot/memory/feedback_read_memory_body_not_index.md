---
name: feedback-read-memory-body-not-index
description: "memory 的 description/索引行可能過時,做決策前要讀 body;證據要綁在被驗的那個 artifact 上"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f9add69a-2dc7-4592-8819-54b71c206a7a
  modified: 2026-08-11T07:18:15.594Z
---

**MEMORY.md 的索引行(即各檔的 `description:`)可能與 body 相矛盾,而 body 才是最新的。**

2026-08-11 實例:`project_build_tree_and_container` 的 description 寫「最後卡 HSM 簽章**由使用者跑**」,但 body 早在 2026-08-09 就明確推翻:「使用者明示要**我自己跑**這步(原本記載是『由使用者執行』,已不適用)」。我只讀了索引行,把錯的寫進交接文件,被另一個 session 抓到。

**How to apply:** 任何要寫進文件、交接、或決定要不要動手的結論,**開啟該 memory 檔讀 body**,不要只憑 MEMORY.md 那一行。索引行只用來判斷「這條相不相關」。

**Why:** description 是寫入當下的摘要,body 更新時不一定會同步回去。

---

同源的一般化教訓(同一天連續踩到 9 次):**把範圍較窄的證據寫成範圍較寬的結論。**

- 「本專案的 diff 沒動它」≠「它沒被改過」(net-snmp 樹本來就帶 26 檔 Moxa 改動)
- 「熱套用版本上驗過」≠「已驗證」(燒錄的 image 是另一個 artifact)
- 「兩棵樹差異 94 個檔案」≠「這棵樹有 94 個」

**How to apply:** 寫斷言時明確標出證據涵蓋的範圍(哪個 build、哪個 partition、哪次量測),不要把它省略成無限定的陳述。

相關:[[project-build-tree-and-container]]、[[feedback-verify-completeness-and-perf]]
