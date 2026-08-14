---
name: project_delegation_completeness_judge_by_mib
description: "委派後比完整性要比『欄位(MIB 物件)』不是 varbind 總數,少掉的欄位一定要查 MAX-ACCESS;ISS db.h 有宣告不等於 ISS 真的服務"
metadata: 
  node_type: memory
  type: project
  originSessionId: d3f32579-7f66-464a-b856-526a67163a15
  modified: 2026-08-08T11:01:29.279Z
---

2026-08-08 搬 `mxrstpdb/` 時確立的判準。

## 比完整性要比欄位,不是 varbind 數

`.603.3.2` 委派後 235 → 227 varbind,看起來像回歸。但拆到**欄位(MIB 物件)**層級:
mainline **25 欄** → 委派後 **27 欄**,每個 accessible 欄位的列數都還是 11,一個沒少。

差異全來自兩件不是「物件消失」的事:
1. 一個 `not-accessible` 的 index 欄不再露出(本來就不該露出)
2. 一列的 index 從 13 換成 29(instance 換鍵,不是欄位消失)

**方法**:`sed 's/\.[0-9]*$//' | sort -u` 取欄位集合再 `comm`,並逐欄比列數。
只比總數會把「多回很多但換了 instance」誤判成回歸 —— dot3 那次也踩過同樣的陷阱。

## 少掉的欄位一定要查 MAX-ACCESS

`rstpStatPortIndex`(`.603.3.2.2.1.1.1`)在 `snmp_moxa_mib/private/mxRstp.mib` 是
**`not-accessible`** → 委派後回 `No Such Instance` 是**對的**,mainline 回 11 個
instance 才不符 MIB。

⚠️ 兩個方向都出現過,不能預設哪邊對:
- mxTurboRingV2 的 index 欄是 `read-only` → **mainline 少回,我們對**
- mxRstp 的 index 欄是 `not-accessible` → **mainline 多回,我們對**

## ISS `db.h` 有宣告 ≠ ISS 真的服務

篩選時 `mxRstpdb.h` 明明宣告了 `.603.3.2.2.1.1.1`,但委派後那欄 targeted walk 與
exact GET 都是 `No Such Instance`。**db.h 宣告是必要條件不是充分條件** —— index 欄
在 ISS 側是 not-accessible。做涵蓋率篩選時要知道這個 100% 會高估。

## in-master 的 port index 不是 ifIndex

這台 DUT 的 ifTable index 是 `1–12, 29, 130, 131`,**沒有 13**。in-master 把第 13 個
RSTP port 依序編成 13(不存在的 ifIndex),ISS 用真正的 29(LAG,ifDescr `" - "`)。
→ **ISS 對**。查證方法:`snmpget .1.3.6.1.2.1.2.2.1.2.<n>` 看該 ifIndex 存不存在。

**副作用(已記在 commit `b5e6745`)**:config 表留 in-master 仍用 13、status 表委派後
用 29,同一 MIB 兩表對同一個 port 鍵不一致。委派前兩邊都是 13(一致但都錯)。

相關:[[feedback_verify_completeness_and_perf]]、[[project_framework_vs_mainline_snmp_diffs]]、
[[project_iss_coverage_screen_before_delegating]]
