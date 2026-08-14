---
name: feedback_no_pipes_on_long_running_commands
description: 長時間指令不要接 | tail / | sed — exit code 會變成管線末端的 0、輸出會被緩衝到結束才吐;一次把編譯失敗回報成成功
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 866e21a4-9a43-4cf9-8e46-6d4b75d0b7f7
  modified: 2026-08-12T19:32:24.864Z
---

**背景或長時間執行的指令,輸出寫檔,不要接管線。**

```bash
cmd > /path/log 2>&1; echo "EXIT=$?"      # ✅
cmd 2>&1 | tail -12                        # ❌
```

**Why:** 2026-08-12 同一個形狀踩了三次,第三次最貴:

| 管線 | 後果 |
|---|---|
| `expect … \| sed -n '/A/,/B/p'` | 輸出被緩衝住,看起來像 DUT 卡死,白等兩輪 |
| `swu_examine --flash \| tail` | 燒錄全程看不到進度 |
| `rebuild.sh \| tail` | **exit code 變成 `tail` 的 0** —— 編譯失敗被回報成 exit 0,差點拿一顆沒編出來的 image 往下走 |

第三個之所以危險,是因為它**把失敗偽裝成成功**,而不是讓事情停下來。

**How to apply:**

- 背景指令一律 `> file 2>&1` 然後單獨 `echo "EXIT=$?"`;要看內容再另外讀檔。
- 真的需要管線時,用 `${PIPESTATUS[0]}` 取真正的 exit code,不要用 `$?`。
- 命令替換 `out=$(cmd | sed …)` **沒有緩衝問題**(它會讀到 EOF),
  但一樣會吃掉 exit code。
- 收到「exit 0」時,**如果那個指令的產出是檔案或 image,去驗產出物**,
  不要只信回傳值 —— 見 `~/mds4xgl3/rebuild_snmp_plan_e.sh` 結尾那句
  「a green build is not evidence」。

相關:[[project_rtk_hook_truncates_grep_redirect]](同一類:管線/重導向讓輸出與事實脫節)、
[[project_build_seq_needs_3rdparty_net_snmp]]。
