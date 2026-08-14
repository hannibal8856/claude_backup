---
name: project_getfwd_probe_must_be_wire_verified
description: GET-forward 規則的 probe 必須用 pcap 證實會產生 Get-PDU;『GET 回得到值』不是證據。mxPort 的 portConfig 側其實沒搬到 ISS
metadata: 
  node_type: memory
  type: project
  originSessionId: 03565926-6fb8-4a69-a12c-4471723877ba
  modified: 2026-08-10T08:12:09.726Z
---

2026-08-07 把 `mox_iss_get_forward_rules[]` 從 4 條(ifTable/ifXTable)推廣到 mxPort 的
8 個 RW 欄,失敗兩輪才找到原因。

**probe 的驗證方式:抓 lo:705 的 pcap,確認該 OID 產生 Get-PDU。**
我當初只確認「`snmpget` 回得到值」就當作 probe 合格 —— 那完全不成立,in-master 也會回值。

`mox_snmp_forward_get_to_iss()` 用 `netsnmp_subtree_find(probe_oid,…)` 定位 ISS 的
reginfo。probe 若其實由 in-master 服務,它會找到**本地**的 subtree、卻仍回 0(當成成功),
把 detached 的請求交給本地 handler → 症狀是:值型別錯(OCTET STRING 變 `INTEGER: 0`)、
scalar 回 `No Such Instance`、GETNEXT 在該欄迴圈(`.2.12` 之後回 `.2.1`)導致
`OID not increasing`,而且 **wire 上完全沒有 AgentX 流量**。整棵 mxPort walk 193 → 13。

**mxPort 的 RO 欄歸屬是分裂的**(pcap 實測,2026_0807_1842):

| RO 欄 | 誰服務 | 能當 probe |
|---|---|---|
| `portConfigTable` col 1 `.603.1.1.1.1.1.1` | in-master | ✗ |
| `portConfigLinkUpDelayTable` col 1 `.603.1.1.1.3.1.1` | in-master | ✗ |
| `portStatTable` col 1–5 `.603.1.1.2.1.1.*` | **ISS** | ✓ |
| `portStatLinkUpDelayTable` col 1–2 `.603.1.1.2.2.1.*` | **ISS** | ✓ |

所以 `mxportdb/` 的委派**實際上只有 status 側兩張表生效,config 側兩張表沒搬** ——
那兩欄是 RO + `mxportdb/` 前綴、照規則該被 skip 卻仍由 in-master 回答,ADR-0012 沒記到。
早期線索:連續 walk 的逐欄分佈裡 `1.1.1.1` / `1.3.1.1` 不出現,`2.1.1.1` / `2.2.1.1` 出現
—— 我當時誤判成 ADR-0011 的 walk 缺陷而略過。

**既有 4 條規則是健康的**(同日實測):ifTable 330 / ifXTable 285 完整走完,
`ifAdminStatus` 與 `ifAlias` 值與型別正確且 pcap 證實走 ISS;`ifAdminStatus` 的
SET→GET 讀回一致(SET 走本地、GET 走 ISS 不會不同步)。`ifAlias` SET 回 `badValue`,
但 mainline 同樣如此 → 既有行為。四條裡實際 SET 得動的只有 `ifAdminStatus`。

**修正後證實可行(2026-08-08,build `2026_0808_0336`,完整燒錄非 hotswap)。**
把 8 條規則的 probe 全改成 `portStatIndex.1` = `.1.3.6.1.4.1.8691.603.1.1.2.1.1.1.1`
(pcap 證實走 ISS)之後:walk 回到 193 筆、16 個欄組齊全、8 個 RW 值與型別全對
(`portConfigDescription` 回到 `""`、scalar 回到 `INTEGER: 1`),且 pcap 確認
**5/5 受測 RW 欄的 GET 都產生 Get-PDU 送到 ISS**,含 scalar `.603.1.1.1.2.0`。

→ **機制可推廣,不是只有 ifTable/ifXTable 能用的特例。** scalar 那條也證實:ISS 用單一
`SNMPRegisterMibWithLock(&mxPortOID, &mxPortEntry, …)` 註冊整個 mxPort,所以 portStat
的 probe 能解析到涵蓋 portConfig 欄位的同一個 registration —— probe 不必和欄位同表。

**但這個應用淨值為負,建議不要合入。** walk 中位數:mainline 154 筆 / 0.757s、
planE RO-only 193 筆 / **0.694s**、加了 RW forward 193 筆 / **0.772s** —— 穩定慢 ~11%。
mxPort 的 RW 欄本地讀取本來就不慢(不是註解說的 600ms value-file 那種),forward 只是
多付 AgentX 來回。依 ADR-0013「先量 walk 耗時」的判準,0.69 秒的 group 本來就不該為速度動它;
正確性也沒收益,那 8 個值本來就是對的。

**2026-08-10 補:pcap 量測本身有三個會靜默給錯答案的坑**(mxRstp 加 `+getfwd`,ADR-0024)。

1. **DUT 上沒有 `timeout`。** `timeout 8 tcpdump …` 直接 `command not found`,tcpdump 從未啟動,
   視窗全回 0 —— 而 0 正好是「沒轉發」的預期值,**看起來像實驗成功否定了假說,其實是空跑**。
   是正對照(已知必然委派的 RO 欄)同樣回 0 才揭穿。**每個視窗都要配正對照。**
   替代寫法:`nohup tcpdump -U -w /tmp/x.pcap port 705 &` 一直開著,各視窗只讀累計數取差值。
2. **`:705` 是共用的** —— framework subagent 也連在上面,背景 6–16 pkt/s。只過濾 port 705
   分不出來。要用 `ss -tnp | grep ISS` 取 `ISS.exe` 的 ephemeral port 再 `tcpdump -r … port <n>`;
   **該 port 每次 snmpd 重啟都會變**,重啟後要重抓。
3. **20 次取樣不夠** —— 3 秒視窗的背景就 ~20 個封包,和訊號同數量級,正負對照量不出差異
   (實際發生過:負對照 33、正對照 36)。拉到 150 次才把比值拉開到 9.5 倍(+286 vs +30)。

另:**`+getfwd` 的成本不能從 mxPort 外推。** mxPort 加了慢 11–13.5%,mxRstp 加了反而
0.66s → 0.63s(完整性不變)。要不要加仍需逐 group 實測。

**How to apply:** 新增 forward 規則時,先對候選 probe 抓一次 pcap;沒看到 Get-PDU 就換一個。
probe 可以跨表,只要落在同一個 ISS registration 內。決定要不要加規則前先量該 group 的 walk 耗時。
相關:[[project_iss_coverage_screen_before_delegating]]、[[project_snmp_walk_slow_diagnosis]]
