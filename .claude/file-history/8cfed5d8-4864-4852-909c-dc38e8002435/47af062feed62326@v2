---
name: commit-message-carries-task-number
description: 執行實作計畫時，commit subject 要帶計畫與 task 編號方便追蹤
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-03T10:26:45.736Z
---

**依實作計畫做事時，commit subject 開頭要帶計畫名與 task 編號**，格式：

```
[Plan E Task 3] ies-auto-mibs: forward GET via subtree children chain
```

**Why:** 使用者在 Plan E 執行到 Task 5 時要求「commit message可以告訴我task數字嗎?
這樣方便我追蹤」。一個 task 常產生多個 commit（實作 + fix round），跨 2-3 個 repo，
沒有編號就無法從 git log 對回計畫的哪一步。

**How to apply:**

- dispatch subagent 時就把完整的 commit message（含編號前綴）寫進指示，
  不要等事後才想到——subagent 只看得到自己那份 brief
- fix round 的 commit 也要帶同一個 task 編號
- 若 commit 尚未推送而使用者想要補編號，可以重寫；但那是他的決定，不要自作主張改歷史

相關：[[report-changed-packages]]、[[build-is-users-job]]
