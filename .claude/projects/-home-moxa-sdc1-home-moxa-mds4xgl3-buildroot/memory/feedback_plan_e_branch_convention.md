---
name: feedback-plan-e-branch-convention
description: "Plan E 改到的每個 package 都用 snmp-plan-E 分支,origin 沒有就直接開新的"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 29daee49-bef3-468c-b065-99511fefffc3
  modified: 2026-08-09T20:16:38.201Z
---

**使用者 2026-08-10 明示:「plugin_moxa_mms 要在 origin 開 snmp-plan-E 新分支。
爾後改到其他 package 時要比照辦理。」**

**How to apply:** Plan E 動到任何一個 dl/ 底下的 package 時:

1. 分支名一律 **`snmp-plan-E`**。
2. origin 上沒有這條分支 → **直接 `git push -u origin snmp-plan-E` 開新的**,不用先問。
3. 該 repo 若是 **detached HEAD**(Plan E 沒動過的 package 常見),
   commit 前先 `git branch snmp-plan-E <commit> && git checkout snmp-plan-E`
   把 commit 從 detached HEAD 救回來 —— 否則下次 checkout 就掉了。
   `plugin_moxa_mms` 就踩過:commit 落在 detached HEAD 上。

**Why:** 讓 Plan E 的所有改動在每個 repo 都用同一個分支名,便於整批追蹤與 MR。

**已知例外**:`plugin_moxa_fiber_check` 用的是既有的 **`snmp-agentx`**(已有 upstream、
上面有 "Act A: Quick win"),不是新開的,所以 2026-08-10 的 `7b552ee` 就地提交在那條。
**要不要統一到 `snmp-plan-E` 尚未與使用者確認。**

相關:[[project-build-tree-and-container]]、[[feedback-build-order]]。
