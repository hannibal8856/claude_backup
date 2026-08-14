---
name: snmpwalk-diff-confounded-by-dut-config
description: DUT 的 CLI 設定（VLAN、IP interface、trust-access…）會改變 OID 集合；兩份 capture 設定不同時 walkdiff 不可信
metadata: 
  node_type: memory
  type: project
  originSessionId: fd443d06-0324-4a72-8f27-783cc900eba7
  modified: 2026-08-04T09:18:10.423Z
---

snmpwalk 的結果取決於 DUT 當下的 CLI 設定，不只取決於韌體。設定不同的兩份
capture 做 walkdiff，差異數字沒有意義。

**2026-08-04 實測到的具體證據：**

| | plan-E2（partition 1） | NOS7 mainline（partition 2） |
|---|---|---|
| `ipAdEntAddr` (1.3.6.1.2.1.4.20.1.1) | 2 筆（.127.253、.222.253） | 0 筆 |
| `dot1qVlanStaticName` (17.7.1.4.3.1.1) | 2 筆 | 0 筆 |

兩邊的**欄位**都存在，只是 mainline 那份**沒有列**——純粹是設定差異，不是實作缺口。
另外那次 `missing=4` 也是同一回事：一列 `dot1qVlanStatus=2`（dynamicGvrp）的動態
VLAN，03:18 有、13:53 沒有。

**Why:** 兩個 partition 各有自己的設定存放區，不會同步；而且設定會隨時間漂移。
所以 `missing=0` 這個數字比表面看起來弱——**mainline 設定得比較少，能「消失」的東西
本來就比較少**。這不會推翻已驗收的個別項目（sysObjectID 的值、rstp col 1 的筆數、
ifIndex 是否存在、SET 路徑、延遲）——那些不受設定影響到會翻盤的程度——但概括性的
「沒有 OID 消失」宣稱是受污染的。

**How to apply:**
1. 任何 walkdiff 的結論，先問「兩邊設定一樣嗎」。不一樣就只能比**不受設定影響的
   子樹**，或明講這是弱證據。
2. `tools/capture_baseline.sh` 目前**只存 OID，不存設定**，所以事後無法回推。要它
   可信就得在擷取時一併 snapshot 設定（至少 VLAN、IP interface、trust-access
   IP、port 狀態）。這件事還沒做。
3. 最乾淨的比對是**同一個 partition 前後對比**（換韌體不換設定），而不是
   partition 1 vs partition 2。

參見 [[snmp-work-notes-repo]]。
