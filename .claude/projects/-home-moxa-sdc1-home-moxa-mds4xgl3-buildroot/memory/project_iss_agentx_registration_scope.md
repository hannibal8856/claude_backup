---
name: project-iss-agentx-registration-scope
description: "ISS AgentX 註冊範圍看 *db.h 涵蓋的 OID 分支,不是 tSNMP_OID_TYPE root 長度;RW 不被 skip ≠ RW 在 walk 看得到"
metadata: 
  node_type: memory
  type: project
  originSessionId: 13f6131f-3289-46a0-9662-a2a36f544e35
  modified: 2026-08-06T12:27:15.921Z
---

判斷 ISS subagent 服務哪些 OID 時,**要查 `app_moxa_iss_10_1_0/code/future/<mod>/inc/<mod>db.h`
裡物件定義涵蓋哪些 OID 子分支**,不能用 `tSNMP_OID_TYPE <mod>OID = {len, arr}` 的 root 長度推論
—— 那個 root 只是 SysORTable 的標籤。

反證(2026-08-06 實測):`ifmibOID = {7, {1,3,6,1,2,1,2}}` 只到 `.1.3.6.1.2.1.2`,
但 ISS `ifmibdb.h` 涵蓋 `.1.3.6.1.2.1.31`,而 `.31` 的 walk 完整健康(ifName / ifHCInOctets /
ifRcvAddressTable 全在,且資料是交換器語意 `Slot1/1`、vlan 在 ifIndex 130/131)。

**Why:** 我在這裡推論錯過一次 —— 先建議 `stdethdb/`,再用 root 長度「更正」成
`stdethdb/dot3StatsTable/`,結果那個更正才是錯的(ISS `stdethdb.h` 其實涵蓋
`.10.7.{2,5,9,10,11}` 全部五個分支)。多繞了一輪。

**How to apply:** 評估 `agentx_owned.list` 要不要加新前綴時,先開 ISS 的 `*db.h` 看分支涵蓋,
再對照 `ies-auto-mibs/net_*.h` 需要的 OID。兩者一對一吻合才用整個群組前綴。

第二條(2026-08-06 定案,pcap 實測):**net-snmp master 的連續遍歷,會整段跳過
「緊接在一段空 ISS 區域之後」的 in-master 孤島**,根因是它送出 start > end 的顛倒 search range。

- 單發 `snmpgetnext` / 從子樹起點 walk → 正常走得到
- 從上層整棵樹連續 walk → 那一段被跳過
- 觸發條件(假說,證據強):in-master 保留的 RW 欄剛好是被委派表的**第 1 欄**
  (表根到 col 1 之間那段 ISS 區域是空的)。`dot3PauseAdminMode` 是 col 1 → 中招;
  `ifAdminStatus` 是 col 7、前面有 col 1~6 有資料 → **ifmibdb 實測不受影響**
- **forward rule 修不了它**(master 遍歷階段就跳過了,in-master 的 handler 根本沒被呼叫),
  且會把正常的 exact GET 改送 ISS。不要加

**Why:** 我一開始把它誤判成「ISS 遮蔽 RW 欄」,ADR-0011 初稿就是這樣寫的,後來被 pcap 推翻。

**How to apply:** 量 walk 筆數當基準時,**務必註明是整棵走還是分表走** ——
stdethdb 委派後整棵走 576、分表加總 588,差的 12 筆是這個缺陷不是回歸。

第三條:手改 target 的 `/etc/moxa/netsnmp/agentx_owned.list` **撐不過重開機**(/etc 疑為 tmpfs
overlay),跨重開機的量測前要先 `cat` 確認委派還在,否則會抓到一份沒生效的 pcap。

第四條(ADR-0013,挑候選的首要條件):**先量 `snmpwalk` 耗時,再談其他。**
ISS 的註冊本來就存在、與 list 無關;list 只控制「in-master 要不要**也**註冊」。
- 慢(秒級)→ in-master 在服務且走 600ms 慢路徑 → 委派可能有收益
- 快(~1 秒內)→ **ISS 早已在服務 → 委派無益**,還可能因拆表損失 index 欄

實證:`stdethdb/` +228、`mxportdb/` +26(兩者 in-master 在服務且實作不全);
`stdladb/` **-12 且零加速**(ISS 本來就在服務)。純唯讀一次 walk 就能判定,
不必改設定、不必重啟 snmpd —— 比舊條件(RO 數量/有無資料/形狀)準得多。

細節與 pcap 證據見 ADR-0011。相關:[[project-agentx-owned-two-axis-design]]、
[[project-agentx-priority-direction-inverted]]、[[project-snmp-walk-slow-diagnosis]]
