---
name: commit-and-build-without-asking
description: 做到一個階段就直接 commit、build、測，不要停下來問使用者要不要提交
metadata: 
  node_type: memory
  type: feedback
  originSessionId: de421898-a940-4237-b2af-265dbd3454a1
  modified: 2026-08-05T07:21:25.744Z
---

Coding 進展到一個段落，**直接 commit、build、然後測效果**，不要先問。
使用者 2026-08-05 明講的。

**Why:** SDD 流程一個 task 常橫跨四五個 repo，每次都問「要提交嗎」是純摩擦；
使用者要的是完成度，不是逐步確認。

**How to apply:**
- commit message 格式見 [[commit-message-carries-task-number]]，
  `[Plan E Task N-M] ...`。
- 只 add 自己動到的路徑。`~/WORK/SNMP_50ms` 和 `buildroot/moxa` 都長期有
  別人留下的未追蹤檔與刪除，不要 `git add -A`。
- **commit 是本機動作；push 仍然要問**（harness 規則），開 GitLab MR 也是。
- build 完要實際驗證，不是看 make 回傳 0——這個 tree 的失敗常常是安靜的，
  見 [[report-changed-packages]] 與 build 目錄有沒有 `-custom` 後綴那件事。
- 例外：第一次動到某個新的 in-master repo（例如 `dl/3rdparty_net_snmp`）
  仍值得先講一聲，那是範圍問題不是提交問題。
