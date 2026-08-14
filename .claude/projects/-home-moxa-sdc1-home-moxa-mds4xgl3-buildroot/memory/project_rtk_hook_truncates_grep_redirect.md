---
name: project-rtk-hook-truncates-grep-redirect
description: "rtk hook 攔截 grep,連 `grep ... > file` 都會寫出被壓縮過的殘缺檔案,靜默不報錯"
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-12T05:32:56.008Z
---

`rtk` 的 Claude Code hook 會把 `grep` 改寫成 `rtk grep`,而 rtk 會**壓縮輸出**。
這不只影響顯示 —— **重導向到檔案時,寫進去的也是被壓縮後的殘缺內容**。

實例(2026-08-12):`grep 'iss_build   = 1,' iss_build.txt > iss_build_1.txt`
應得 1391 行,實得 **203 行**,沒有任何錯誤訊息。用 `wc -l` 才發現。

**Why:** 這類截斷是靜默的 —— 檔案存在、格式正確、內容看起來合理,只是少了 85%。
拿去做集合比對或 completeness 判定會產生看起來很合理的錯誤結論,
跟 [[project_measure_snmp_walk_skill_defects]] 的假 delta=0 是同一類陷阱。

**How to apply:** 要**產生檔案**(不是給人看)的抽取工作,不要用 `grep` 重導向。
改用 `python3 -c` 讀寫,或 `rtk proxy grep ...`(RTK.md 記載的原始命令通道)。
產出後一律用 `wc -l` 或在 python 裡印出計數,與來源總數對帳:
分類結果的各類數量加總必須等於來源行數(例:1391 + 745 + 0 = 2136)。
唯讀查看用的 grep 不受影響,照用即可。

## 追加 2026-08-13:改寫範圍比「grep 重導向」更廣,可能包含**憑空生出條目**

同一個 hook 今天觀察到的其他改寫:

- `git status --porcelain` 的空輸出 → 變成 `ok`
- `grep` 輸出 → 壓成「N matches in M files」,且行首被截斷成 `數字:0:`
- 一次 `wc -l < file` 回 **0**,而 python 讀同一個檔是 **23 行**

🔴 **最嚴重的一則(由 `snmp-plan-F1 designer` 回報,我無法在自己的樹上重現)**:
在一棵**缺少 4 個套件**的 buildroot 樹上,`ls -d lib_moxa_*` 回傳了
`lib_moxa_ies_auto_mibs/`、`lib_moxa_rust_ies_auto_mibs/`、`lib_moxa_rust_snmp_agentx/`
——**這三個目錄在那棵樹上不存在**,`test -d`、純 shell glob、`rtk proxy ls` 三法一致確認 absent。
差一點讓他做出「套件都在」的相反結論。

我在自己的樹上測不出來,**因為那三個目錄在我這裡是真的存在的**。
假說(未證實):輸出可能被某種「這種樹長什麼樣」的既有印象補完 ——
完整的樹剛好補對,缺東西的樹就補出不存在的條目。

**這比其他陷阱惡劣一級**:別的是「工具提早結束/沒查到」,產生的是缺席;
**這個是工具生出看起來完全合理的存在**。缺席還可能被察覺,虛構不會。

### 操作規則(成本近乎零,一律照做)

- **任何「某某存在 / 不存在」的結論**,用 `python3`(`os.path.isdir` / `glob`)
  或 `rtk proxy`,不要用經過 hook 的 `ls`
- **產檔**用 `python3` 或 `rtk proxy`,產完**對帳行數**
- 需要精確計數(`wc -l`、`grep -c`)時同理

相關:[[feedback_absence_claims_need_reach_proof]]、[[feedback_ask_what_you_held_fixed]]
