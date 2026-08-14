---
name: project_measure_snmp_walk_skill_defects
description: measure-snmp-walk 的 fwdcheck 有三個會靜默給出錯誤結論的實作缺陷;小 N 會產生假的 delta=0
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b76eced-c087-4c3e-af48-3a002d2190b4
  modified: 2026-08-13T07:24:02.848Z
---

2026-08-11 實地踩到。`~/.claude/skills/measure-snmp-walk/` 的 `fwdcheck` 這條路徑有
**三個缺陷,共同形狀是「失敗時不報錯,而且產生的數字剛好長得像一個合理結論」**。

| # | 缺陷 | 症狀 |
|---|---|---|
| 1 | `fwdcheck_remote.sh:38` `DUR = IDLE*2 + 90` **寫死,不隨 N 縮放** | N 一大,burst 跑超過擷取時長,`tcpdump` 自行結束,後面視窗讀到靜態檔 → 正對照歸零 → INVALID。**skill 正文要求 N≥150,與自己的實作互相矛盾** |
| 2 | ~~`dutssh.exp` 寫死 `set timeout 300`~~ **已修正,見下方更正** | 遠端腳本超時 → 輸出被截斷 → 外層 `sed` 範圍比對匹配不到結束標記 → **整份輸出靜默消失**(跑十分鐘什麼都拿不到)|
| 3 | `fwdcheck_remote.sh:44` `cnt()` **每次都 `tcpdump -r` 重讀整個 pcap** | 檔案越大越慢,視窗越後面越慢,最後撞上缺陷 2。**實測 200 次 GET 只花 5 秒 —— 慢的是計數,不是量測** |

**⚠️ 最隱蔽的一個:小 N 會產生假的 `delta = 0`。**
N=20 時 burst 太快,封包還沒被 `tcpdump` 寫進檔案就被 `cnt()` 讀走 → `TARGET delta=0`
→ 判定 NOT FORWARDED。同一組 OID 用 N=150 重跑得到 `delta=243`(正對照 267),**方向完全相反**。
**0 往往也正好是「沒有轉發」這個假說的預期值**,所以假的零看起來像完美的證據。
這是 skill trap 2 的變形 —— trap 2 講的是 `timeout` 不存在導致 tcpdump 沒啟動,
**共同形狀都是「工具沒運作」與「假說成立」在輸出上長得一樣**。

## 更正 2026-08-12:缺陷 2 已不成立

實際查證 `~/.claude/skills/measure-snmp-walk/dutssh.exp`:

```
:4  # a long fwdcheck run (large N) exceeds a 300 s timeout and the output is lost
:5  set timeout 900
```

**現值是 900**,而 `:4` 的註解正是記載 300 s 那個**已被修正的舊問題**。上表第 2 列描述的是歷史狀態,
不要再拿「timeout 300」去解釋新的輸出遺失。

⚠️ **但「整份輸出靜默消失」這個症狀仍會發生,只是成因不同。** 2026-08-12 由
`snmp-plan-E reopen 6` 踩到並主動撤回自己的歸因:真因是在 `dutssh.exp` 後面接
`sed -n '/BEGIN/,/END/p'`,**管線緩衝把輸出全吃住**,kill 掉才一次吐出來。
→ 看到「跑很久沒有輸出」時,先懷疑**外層管線的緩衝**(`stdbuf -oL` / 直接落檔),
不要再歸因給 timeout。

## 追加 2026-08-13:`walkpcap.sh` 的 `-G $DUR -W 1` 會在 walk 之前就結束 tcpdump

`walkpcap.sh:40` 用 `tcpdump ... -G $DUR -W 1`。**`-G` 不是「從啟動算 N 秒」,而是對齊絕對時間的整數倍** ——
啟動時若接近邊界,幾百毫秒後就觸發輪替,再被 `-W 1` 的 `Maximum file limit reached: 1` 結束。

**症狀完全正常**:stderr 照樣印 `19 packets captured / 42 received by filter / 0 packets dropped by kernel`,
pcap 檔也真的存在(1.7 KB),裡面是**啟動後那一兩秒的背景 keepalive**。
拿它做判定會得到「零 Get PDU → 沒有轉發」,而那正好是常見假說的預期值。

實測對照(同一支 OID、同一顆 image、只差擷取方法):

```
-G 25 -W 1     1.7 KB    6 Ping / 6 Response / 0 GetNext      ← 什麼都沒拍到
kill -INT      70  KB  201 GetNext / 205 Response / 1 Get     ← 真的有轉發
```

**→ 所有由 `walkpcap.sh` 產出的 pcap 都有這個嫌疑,不只是新的。** 檔案大小是最快的分辨法:
真的有 AgentX 活動的擷取是幾十 KB,1–2 KB 的幾乎一定是空的。

**可用的寫法**(2026-08-13 驗證):同一個 session 內記下 PID、`kill -INT` 收尾,並加三道自我檢查 ——
`kill -0 $TP` 確認 walk 開始時 tcpdump 還活著、回報 walk 的 varbind 數確認它真的跑了、
結束後 `ps | grep -c tcpdump` 確認沒殘留。少任何一道都會讓空擷取看起來像結論。

⚠️ **DUT 上沒有 `timeout` 指令**(`exit 127`),所以不能用 `timeout N tcpdump` 限時。

**⚠️ 這條讓 ADR-0030 的未決題失去翻案素材(2026-08-13 補)。** ADR-0030 那個「為什麼 08-10
量到 NOT SERVED」的懸案,原本的兩條還原路徑是「找回舊判準」與「找回舊 pcap」。判準已確定不在版控;
**而就算找回舊 pcap,只要它是 `walkpcap.sh` 產出的就不可信** —— 空擷取與「沒有轉發」在輸出上一樣。
→ 建議把 ADR-0030 的未決題正式標為**永久未決**,不要再投入考古。

## 繞過方式(已驗證可用)

- **在 DUT 上 `nohup` 背景執行、輸出落檔,再分開 ssh 取回** —— 避開缺陷 2。
- **不要用診斷用的縮水參數形成判斷**。要嘛用足夠的 N,要嘛只拿它來確認腳本會跑。
- **判定拿 TARGET 對 POSITIVE,不要對 NEGATIVE** —— 背景率會漂(實測 0.8–5 pkt/s,跳 6 倍),
  分母不可靠;正對照才是「確定會轉發」的參照物。
- **背景要用多個 idle 視窗平均,每個 burst 記錄耗時再扣掉該時段的預期背景**,
  得到「每次 GET 的淨 AgentX 封包數」,才可跨 OID 比較。
- **腳本開頭先驗每個 OID 都答得出來** —— 原 `burst()` 把 `snmpget` 輸出丟 `/dev/null`
  且不檢查回傳,所以 `No Such Object` 與「未轉發」長得一模一樣。

自訂版留在 session scratchpad 的 `fwd2_remote.sh`(四 idle 視窗 + 扣背景 + 對正對照判定
+ OID 可答性前置檢查)。**skill 本身尚未修改** —— 那是使用者的資產,要改前先問。

相關:[[project_getfwd_noop_on_mxportdb_stdethdb]]、[[project_getfwd_probe_must_be_wire_verified]]
