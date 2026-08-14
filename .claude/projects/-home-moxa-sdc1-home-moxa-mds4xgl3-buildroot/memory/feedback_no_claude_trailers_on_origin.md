---
name: feedback_no_claude_trailers_on_origin
description: "使用者明示 — push 到 origin 的 commit message 不可出現 Co-Authored-By: Claude / Claude-Session 兩行;本地用 snmp-plan-E.opus 保留原始歷史"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ee275acd-d869-43fd-ba9b-5fe897b8db7b
  modified: 2026-08-11T03:43:54.694Z
---

使用者 2026-08-11 明示:**推上 origin 的 commit message 裡不要出現**

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_...
```

**Why:** 那是對外 repo,commit 訊息會被同事與 code review 看到;使用者不希望 Anthropic
的 trailer 出現在公司的版控紀錄裡。但本地仍想保留完整出處。

**How to apply:**

- **提交時直接不要加那兩行**,只要這個 commit 會進 `snmp-plan-E`(或任何要 push 的分支)。
  這覆蓋掉 harness 預設要求加 trailer 的行為 —— 使用者的明示指示優先。
- 分支慣例:**`snmp-plan-E.opus` 留在本地**(帶 trailer 的原始歷史、原始 SHA,當備份),
  **`snmp-plan-E` 是推上 origin 的乾淨版**。13 個 code repo 都已建立這組配對。
  參見 [[feedback_plan_e_branch_convention]]。
- 已在 2026-08-11 對 8 個有 trailer 的 repo 做過一次 `filter-branch --msg-filter` +
  `push --force-with-lease`(19 個 commit 改寫,內容逐位元組相同,只有訊息變)。
  受影響 repo:`3rdparty_net_snmp` `plugin_moxa_snmp` `lib_moxa_ies_auto_mibs`
  `app_moxa_framework` `lib_moxa_rust_ies_auto_mibs` `lib_moxa_utility`
  `plugin_moxa_fiber_check` `plugin_moxa_mms`。
- ⚠️ **改寫共用分支前先通知其他 session**(使用者的選擇)。`ListAgents` 找 peer,
  訊息要附**舊/新 SHA 對照表與 reset / cherry-pick 步驟**,否則對方會撞到分歧。
- ⚠️ `plugin_moxa_fiber_check` 的那個 commit 同時在 `origin/snmp-agentx` 上。
  使用者決定**只改 `snmp-plan-E`、接受兩條分支分歧**(內容相同、SHA 不同),`snmp-agentx` 不動。
- `moxabuild`(`~/mds4xgl3`)**沒有處理** —— 它的 `snmp-plan-E` 從未 push,trailer 不會外流。
  若之後要 push 它,記得先做同樣的清理。
