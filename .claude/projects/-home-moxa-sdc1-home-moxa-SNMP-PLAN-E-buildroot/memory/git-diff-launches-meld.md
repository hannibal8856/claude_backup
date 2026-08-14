---
name: git-diff-launches-meld
description: 這台機器 git diff 會開 meld GUI；一律加 --no-ext-diff，dispatch subagent 時也要交代
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fd443d06-0324-4a72-8f27-783cc900eba7
  modified: 2026-08-04T06:54:20.209Z
---

這台機器的 git 設定了 `diff.external = /home/moxa/git-meld.sh`，所以任何 `git diff`
都會彈出 meld 視窗打斷使用者。改用：

```
git --no-pager diff --no-ext-diff <args>
```

`--no-ext-diff` 是關鍵（`--no-pager` 只擋 pager，擋不掉 external diff）。
`git show`、`git log -p` 同樣受影響，同樣加 `--no-ext-diff`。

**Why:** 使用者在 code review 進行到一半時被 meld 視窗打斷才發現的。

**How to apply:** 自己下指令時直接加旗標；更重要的是**派 subagent 做 code review 或
任何要讀 diff 的工作時，必須在 prompt 裡明講**——subagent 不會知道這件事，而它們正是
最會直接打 `git diff <range>` 的一方。參見 [[report-changed-packages]]、
[[build-is-users-job]]。
