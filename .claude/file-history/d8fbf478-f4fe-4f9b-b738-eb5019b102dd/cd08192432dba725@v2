---
name: project_getfwd_noop_on_mxportdb_stdethdb
description: "⚠️『+getfwd 對 mxportdb/stdethdb 靜默無效』已於 2026-08-12 被封包推翻(四個前綴皆會轉發,成因待查);仍成立的是『生效≠有效果』——對 walk 時間無可測量影響"
metadata: 
  node_type: memory
  type: project
  originSessionId: ee275acd-d869-43fd-ba9b-5fe897b8db7b
  modified: 2026-08-12T08:50:04.993Z
---

# 🔴 已被推翻(2026-08-12,ADR-0030)—— 本檔的核心主張不成立

**四個 prefix 全部都會轉發,「靜默無效」這個缺陷不存在。** 由 `snmp-plan-E reopen 6`
用帶 trace 的 debug image + `tcpdump -i lo tcp port 705`(366 captured / 0 dropped)證實:
五個 AgentX **Get PDU (type 5, session 6)** 送往 `127.0.0.1:49882` = `ISS.exe` (pid 297),
涵蓋 `ifmibdb/`(ifTable + ifXTable)、`stdethdb/`(dot3PauseTable)、
`mxportdb/`(portConfigTable)、`mxrstpdb/`(scalar),
`access_method` 五個都是同一個指標值 `0xb6f51688`。

**為什麼與本檔的 2026-08-10 結論不同,尚未定案**(ADR-0030 記為未決,不猜):
(a) 當時的判定來自還有缺陷的 `fwdcheck.sh`;(b) 這次是四條同時開啟(`scanned=101`),
當時可能是單獨開啟。

**下面的內容保留作為歷史紀錄與方法論教訓,但「不轉發」這個結論不可再引用。**
仍然有效的部分:①「生效 ≠ 有效果」(mxRstp 有轉發但 ADR-0024 的 0.66→0.63 落在量測
重複性之內);②`ifmibdb/` 當時沒有正面封包佐證(現在有了);③ 加 `+getfwd` 要先問
「有沒有轉發」再問「有沒有變快」。

⚠️ 方法論教訓:**封包「統計計數」判準不如「直接解 PDU 內容比對 OID」穩健。**
366 個封包裡只有 12 個非 keepalive —— 直接解碼比對,不需要正負對照,也不會被背景率漂移騙。

---

（以下為原始記錄,結論已被推翻)

2026-08-10 實測(ADR-0025)。**在當前 code base 上,`agentx_owned.list` 的 `+getfwd`
對 `mxportdb/` 與 `stdethdb/` 完全不生效** —— 加了旗標也不會把 RW 欄的 GET 轉發給 ISS。

**證據**(只計 ISS 自己那條 AgentX TCP stream,每項 150 次 GET):

| 動作 | Δ 封包 |
|---|---|
| 空窗 15s | +42(背景 ≈ 5.9 pkt/s) |
| mxPort config RW 表欄 / scalar RW / LinkUpDelay RW | +30 / +30 / +39 → **背景級,未轉發** |
| dot3 唯一 RW `Dot3PauseAdminMode` | +30 → **未轉發** |
| mxPort status RO(正對照) | +333 |
| **mxRstp config RW(同一顆 snmpd instance)** | **+327 → 機制本身是好的** |

**不是 2026-08-07 那個失效模式。** 那個(build `2026_0807_1842`)是 probe 指到本地
registration → 錯誤型別、`OID not increasing`、walk 從 193 崩到 12 vb。這次**值與型別全對、
walk 193 vb / 16 欄正常、時間也沒變**,走的是乾淨的 fall-through 回本地。剩兩個候選路徑:
`mox_snmp_probe_for_entry()` 回 NULL,或 `mox_snmp_forward_get_to_iss()` 回 -1。
**兩條都是靜默的,黑箱分不出來**,要加 trace 編 debug image 才能釘死。**根因未定位。**

**連帶影響**:ADR-0014 記的「mxPort 加 `+getfwd` 慢 13.5%」**在當前 code base 上無法重現**
(因為根本不轉發),不可再引用為「轉發成本」的證據。可用的正確數字來自 08-08 三顆 image
的 pcap:opt-in 後 0.691s → 推導全轉發 0.779s = **+12.7%**。

**不急著修的理由**:就算修好,mxPort 開 `+getfwd` 是 0.779s,比 RO-only 的 0.691s 慢,
**也比 NOS 7 mainline 的 0.768s 慢** —— 對 mxPort 是負值。只有在篩到第三個值得開的 group
時才需要處理這個推導缺陷;目前唯一划算的 mxRstp 本來就能用。

**目前 `+getfwd` 真正生效的只有兩條**:`ifmibdb/`(出貨既有,手工 probe 年代留下的)與
`mxrstpdb/`(ADR-0024)。

---

## 2026-08-11 補正(燒錄版 `2026_0811_1349`)

**1. `mxrstpdb/` 在燒錄版上已封包證實生效** —— 先前只在**熱套用**版本驗過,兩者是不同
artifact,不可互推。自訂量測(四個 idle 視窗平均背景率、每個 burst 扣掉該時段預期背景,N=200):

| | 每次 GET 淨 AgentX 封包 |
|---|---|
| TARGET `.603.3.2.1.1.0`(mxRstp RW 欄)| **1.950** |
| POSITIVE(確定走 AgentX)| **1.875** |
| NEGATIVE(確定不走)| **0.000** |

TARGET = 正對照的 104%,三者完全分離。1.95 ≈ 一次 AgentX 往返的 request+response。

**2. ⚠️ 但「生效」不等於「有效果」。** 交錯量測(A→B→A2,各 9 輪):

| | 開啟 `+getfwd` 前 | 開啟後 |
|---|---|---|
| A | 0.620 s | 0.632 s |
| A2 | 0.653 s | 0.654 s |

**ADR-0024 記載的 0.66→0.63(0.03 s)與 A↔A2 重複性(0.022–0.033 s)同量級,從一開始
就小於量測雜訊**(skill trap 5)。**ADR-0024 的那組數字應重新標為「在量測重複性之內,
不構成效應」。** mxRstp 頭條的 48 倍來自**唯讀欄委派**,不是這個旗標。

**3. `ifmibdb/` 從來沒有正面的封包佐證。** ADR-0014 只寫「必須用 pcap 驗」,那是要求不是
結果。不要再說它「已驗證轉發」。

**How to apply(補充):** 加 `+getfwd` 要問**兩個**問題,而且順序不能顛倒 ——
先問「**有沒有轉發**」(封包判定),再問「**有沒有變快**」(交錯量測)。
兩者都要,且**答案可以是「有轉發但沒變快」** —— 那時正確的做法是照實寫,不要為了讓旗標
顯得有用而去挑一組看起來有差的數字。相關:[[project_measure_snmp_walk_skill_defects]]

**How to apply:** 任何時候在 `agentx_owned.list` 加 `+getfwd`,**一定要用 pcap 驗轉發真的發生**
(方法見 [[project_getfwd_probe_must_be_wire_verified]]),不能只看 walk 時間有沒有變 ——
「沒變慢」可能只代表「根本沒轉發」。相關:[[project_registration_count_hypothesis_refuted]]


---

## 🔴 2026-08-12 推翻:四個前綴其實都會轉發

`snmp-plan-E reopen 6` 編了 trace image `2026_0812_1532`(在 `ies_auto_mibs.c` 的轉發路徑
加 instrument),燒到 p1,四個前綴各跑可寫欄 `snmpget` 並同時 `tcpdump tcp port 705`。

**抓到五個 AgentX Get PDU(type 5, session 6),對端 = `ISS.exe`:**

| prefix | 解碼後的 OID |
|---|---|
| `ifmibdb/` | `.1.3.6.1.2.1.2.2.1.7.1`(ifAdminStatus)、`.1.3.6.1.2.1.31.1.1.1.18.1`(ifAlias)|
| `stdethdb/` | `.1.3.6.1.2.1.10.7.10.1.1.1`(Dot3PauseAdminMode)|
| `mxportdb/` | `.1.3.6.1.4.1.8691.603.1.1.1.1.1.2.1` |
| `mxrstpdb/` | `.1.3.6.1.4.1.8691.603.3.2.1.1.0` |

process 內部 trace 也顯示四關全過(gate → probe 選擇 → subtree 解析 → `fwd_rc=0 FORWARDED`)。
**兩層獨立證據一致。** 證據檔:`~/pcap/2026-08-12-getfwd-optin-4prefix-2026_0812_1532.pcap`
(含 `.tcpdump.log` sidecar 與 `.trace.txt`)。

**`ifmibdb/` 這下也有封包證據了** —— 它自 ADR-0028 收回宣稱後一直是未驗證狀態。

### ⚠️ 兩個界線

1. **範圍**:每個前綴各測 1–2 個可寫欄 / 1–2 張表,**不等於「所有可寫欄都會轉發」**。
   轉發的選擇以**表(URI)**為單位,某張表若候選全被遮蔽且 fallback 落空仍可能失敗。
   `stdethdb/` 例外 —— 它只有一個可寫欄,那格是完整的。
2. **為什麼與先前判定不同,尚未定案。** 兩個候選:(a) 先前判定用的 `fwdcheck.sh` 當時
   判準與 `PEER` 參數都有缺陷(2026-08-12 才修);(b) 這次四條前綴同時開啟、候選池 101,
   先前可能是單獨開啟。**在查清楚前只寫「已被推翻,成因待查」,不要選一個原因寫上去。**

**仍然成立的部分**:`mxrstpdb/` 的 `+getfwd` **生效但對 walk 時間無可測量影響**
(0.620/0.653 → 0.632/0.654,落在重複性之內)。**「有沒有轉發」與「有沒有變快」
仍是兩個問題。**
