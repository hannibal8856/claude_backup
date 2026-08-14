---
name: project-dut-dual-image-ab-pair
description: "DUT dual image A/B 配置 — partition 1=Plan E 2026_0730_1302(可覆蓋)、partition 2=NOS 7 mainline 2026_0805_2335(對照組,必須存活);燒錄一定要從 0805 那側跑"
metadata: 
  node_type: memory
  type: project
  originSessionId: 13f6131f-3289-46a0-9662-a2a36f544e35
  modified: 2026-08-14T01:17:23.596Z
---

DUT(192.168.127.253,MDS-G4000-L3-4XGS)是 dual image,兩側固定分工:

| partition | image | BUILD_TIME | 角色 |
|---|---|---|---|
| 1 | Plan E | ~~`2026_0730_1302`~~ → **`2026_0813_0905`**(2026-08-14 實查) | 開發版,**要覆蓋的就是這一側** |
| 2 | NOS 7 mainline | `2026_0805_2335` | **對照組,必須存活** |

**角色分工固定,但「現在開在哪一側」是會變的執行期狀態。**

🔴 **這張表的 image 欄本身就過期過一次**(p1 從 `0730_1302` 換成 `0813_0905`,
本筆記憶隔了 8 天才更正)。**燒錄前一律實查,不要信任何人記的值**,包括這一筆:

```bash
fw_printenv fwrbootpart ; cat /etc/moxa/version/BUILD_TIME
```

⚠️ **交還 DUT 之後,自己記的狀態一律視為過期。**
2026-08-14 實例:我最後一次接觸時是 p2,交還後 `reopen 7` 切到 p1 做實驗;
我在交接清單裡照舊寫「DUT 在 p2」,**若對方照著在 p1 上燒,寫入的就是 p2 = 對照組**。
被 `reopen 7` 當場更正。(這條原是 `reopen 6` 交接時對 `reopen 7` 說的,當天反過來成立。)

**swupdate 永遠寫「你沒開在上面的那一側」**,所以要燒新的 Plan E build:
先 `printf 'Y\nY\n' | /moxa/fwr_change.sh` 切到 **0805 對照組**、等重開機(~40s)、
**再**跑 swupdate。新版本會落在 partition 1,`fwrbootpart` 翻回 1。

反過來(開在 0730 跑 swupdate)會把對照組蓋掉。

兩側都能用 admin/moxa 登入,再 `su`(同密碼)取 root。

**Why:** 對照組是把「Plan E 弄壞的」和「本來就壞的」分開的唯一手段。
2026-08-06 測 `stdethdb/` 委派時,就是靠 0805 證明 `dot3PauseAdminMode` 的
`snmpset badValue` 兩邊一模一樣、屬既有狀態而非 delegation 造成(見 ADR-0011)。
弄丟它要重燒,而且期間做的所有比對都失效。

**How to apply:** 用 `examinate-plan-e-swu` skill,它有兩道獨立 gate:
`--protect 2`(擋 partition 編號)+ `--control-build 2026_0805_2335`
(stage 3 斷言執行中的 BUILD_TIME 真的是對照組,擋「partition 2 已經不是對照組」
這種編號 gate 看不到的情況)。對照組若正式換版,要同步更新該 skill 的預設值與本筆記憶。

相關:[[project-iss-agentx-registration-scope]]
