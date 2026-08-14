---
name: project-swu-lives-in-two-places
description: .swu 有兩個位置(output/images 會被 make 刪、~/swu 是備份);只查一邊就宣告「沒有副本」會做出錯誤的破壞性決策
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-12T07:14:58.959Z
---

`.swu` 韌體檔同時存在於**兩個**位置,查「某個 BUILD_TIME 還有沒有副本」時**兩邊都要查**:

| 位置 | 性質 |
|---|---|
| `~/mds4xgl3/buildroot/output/images/` | **build 產出** —— 下一次 `make` 會刪掉 |
| `~/swu/` | **手動備份** —— 需要有人 `cp` 過去才會有 |

每顆 image 是 `.swu` + `.swu.header` **一對**,header 固定比 .swu 大 **32 bytes**
(可用這個差值快速判斷檔案完整、不是半成品)。

**Why:** 2026-08-12 差點因此做出破壞性決策。`snmp-plan-E reopen 6` 只查了 `~/swu/`
就宣告 `2026_0812_1136`「只存在於 DUT 的 p1」,推導出「燒 debug image 就得犧牲它、
且重建的 BUILD_TIME 會變所以救不回」。實際上 `output/images/` 裡完整存在
(68,013,568 bytes,md5 `3d078ff5fd49dd1f760c67e157652109`)。
**錯誤的形狀是「查證範圍窄於結論範圍」** —— 查一個目錄,結論卻涵蓋所有位置。

**How to apply:** 要判斷某顆 image 能不能被覆蓋,先兩個目錄都 `ls`;確認在不在
`~/swu/`,不在就先 `cp -n` 過去再動 build(**用 `-n` 不用 `-p`**,理由見下)。
**注意 `cp -p` / `cp -a` 會保留 mtime(= build 時間),所以「何時進備份目錄」
要看 `ctime` 不是 `mtime`。** 複製後 `md5sum` 兩邊對帳。

**build 完就立刻 `cp` 到 `~/swu/`**,不要等到要用時才找 —— 保存的時機只有
「被下一次 `make` 清掉之前」。

**重建救不回一顆特定 image**:從同樣的 commit 重建,BUILD_TIME 會是新的,而 BUILD_TIME
正是 pcap 檔名與 ADR 驗收段落的識別碼(例:`~/pcap/2026-08-12-evtPort-A-2026_0812_1136.pcapng`、
ADR-0029 ③「image `2026_0812_1136`, DUT p1」)。重建品冒充不了原檔,燒上去
`cat /etc/moxa/version/BUILD_TIME` 就對不上。**所以「大不了重編」不是退路。**

⚠️ **搶同一個檔案時,先廣播來不及。** 那次 `snmp outline CIC 3` 在 15:11:14 複製、
`reopen 6` 在 15:11:33 也要複製 —— 相隔 19 秒。ADR-0027 ③ 的「動共用資源先廣播」在這個
時間尺度救不了,救到的是 **`cp -n`**(不覆蓋既有檔)。對共用檔案的寫入一律加冪等旗標,
不要只依賴廣播。相關:[[feedback_cross_session_handoff_discipline]]、
[[project_build_seq_needs_3rdparty_net_snmp]]、[[project_dut_dual_image_ab_pair]]。
