---
name: feedback_verify_completeness_and_perf
description: "每次改 SNMP code 測試都要同時看兩件事:對 mainline 的完整性不能少,效能不能比原本 agentx_owned.list 差"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 03565926-6fb8-4a69-a12c-4471723877ba
  modified: 2026-08-08T02:03:32.889Z
---

2026-08-08 使用者明示:**每一次改完 code 的測試,都要同時關注這兩項**,不能只看功能對不對。

1. **完整性** —— 與 NOS 7 mainline 對照,varbind 數不能少(少了就是回歸)。
2. **效能** —— 不能比**改動前的 `agentx_owned.list` 版本**差。基準線是那一版,不是 mainline。

**Why:** `agentx_owned.list` 機制存在的理由就是速度(RW 欄走本地 value-file ~600ms 會拖垮整張表的
多 varbind GETNEXT)。一個讓 walk 變慢的改動即使功能正確,也違背機制的初衷。

**已知基準線(mxPort `.1.3.6.1.4.1.8691.603.1.1`,5 次取中位數,PC 端 `/usr/bin/snmpwalk`):**

| image | varbinds | 中位數 |
|---|---|---|
| mainline `2026_0805_2335` | 154 | 0.757s |
| planE RO-only `2026_0806_1730`(**效能基準線**) | 193 | **0.694s** |
| planE + RW GET-forward(手列 probe)`2026_0808_0336` | 193 | 0.772s(**慢 11%,不符**) |
| planE + RW GET-forward(自動推導 probe)`2026_0808_0507` | 193 | 0.788s(**慢 13.5%,不符**) |
| planE 逐行 opt-in(`ifmibdb/ +getfwd`)`2026_0808_0844` | 193 | **0.700s(合格,回到基準線)** |

**2026-08-08 量到的四棵樹完整基線**(5 次中位數,同一天同一台 DUT,mainline 在 p2、planE 在 p1):

| 樹 | mainline `0805_2335` | planE opt-in `0808_0844` |
|---|---|---|
| mxPort `.8691.603.1.1` | 154 / 0.783s | 193 / 0.681s |
| dot3 `.1.3.6.1.2.1.10.7` | **329 / 1.131s** | **581 / 1.578s** |
| ifTable `.1.3.6.1.2.1.2.2` | 330 / 1.440s | 330 / 0.895s |
| ifXTable `.1.3.6.1.2.1.31.1.1` | 285 / 1.375s | 285 / 0.788s |

dot3 用**集合比對**驗過(不是只比數量):mainline 的 OID **一個都沒少**
(`comm -23` 為 0),planE 多 17 個欄位(含整張 dot3CollTable)。
注意 `.10.7` 這棵樹 planE 比 mainline 慢,但那是因為多回 77% 的資料;
**每 varbind 反而更快**(2.72ms vs 3.44ms)。比 walk 總時間會誤判。

自動推導那版功能全過(ifTable 330 / ifXTable 285 / dot3 594 皆無減少,4/4 group 的 RW GET
都有 Get-PDU,含 `ifmibdb/` 底下 ifTable 與 ifXTable 兩個不同 registration),**只有效能不過**。
原因是政策太粗暴:它讓「委派 group 裡的每一個 RW 欄」都 forward,而 mxPort 的 RW 欄本地讀取
本來就不慢。提議的解法是把 forward 改成清單逐行 opt-in(例如 `ifmibdb/  +getfwd`)——
原本手列的 4 條規則全都在 `ifmibdb/` 底下,所以只給該行加旗標即與出貨版行為等價。
dot3 的 forward 是自動推導版才新啟用的,**沒有 before 耗時數字**,尚無法判定是否變慢。

**「第 1 欄從連續 walk 消失」是 mainline 也有的行為,不是 planE 的回歸** —— 2026-08-08 實測:
`.10.7.10.1.1`(dot3PauseAdminMode)在 **mainline 與 planE 兩邊都不出現在連續 walk**,
但兩邊 targeted walk / exact GET 都回得到 13 筆。所以 ADR-0011 那個缺陷拿 mainline 當
基準時**不算少**。判斷完整性一定要做**集合比對**,只比總筆數會把「多回很多但少一欄」
誤讀成回歸。

**How to apply:** 驗收固定跑這套 —— walk 筆數 + 逐欄分佈 + 值與型別 + lo:705 pcap 確認 Get-PDU,
再加上與上表兩條基準線的比對。量測腳本 `~/mds4xgl3/tools/walkmeasure.sh`,pcap 一律留到 `~/pcap/`,
檔名格式 `<YYYY-MM-DD>_<主題>_<planE|mainline>_<BUILD_TIME>[_<變體>].pcap`。
相關:[[project_getfwd_probe_must_be_wire_verified]]、[[feedback-dut-operation-authorization]]
