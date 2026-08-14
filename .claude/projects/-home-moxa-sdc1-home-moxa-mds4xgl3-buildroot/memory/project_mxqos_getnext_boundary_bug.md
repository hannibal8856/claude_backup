---
name: project_mxqos_getnext_boundary_bug
description: "mxQos 整棵 walk 只拿得到 434 個 varbind 中的 73 個;GETNEXT 在兩個邊界回傳請求的 OID 自己,-Cc 會無限迴圈"
metadata: 
  node_type: memory
  type: project
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T07:00:49.224Z
---

2026-08-13 在 `2026_0813_0905` 上量到,交接把它記成「既有缺陷」但低估了嚴重性。

## 形狀:GETNEXT 在邊界回傳「請求的 OID 自己」

```
GETNEXT .603.2.9.1.3       → .603.2.9.1.3 = NULL         (應為 .603.2.9.1.3.1.2.1)
GETNEXT .603.2.9.1.2.1.2.7 → .603.2.9.1.2.1.2.7          (應跨到 .1.3)
```

兩處是同一個 bug 的兩次發作。後果:**任何標準 walk 在 `.1.2` 就以
`Error: OID not increasing` 中止,只拿到 434 個 varbind 中的 73 個(17%)。**
逐表 walk(`.1.1`…`.1.7` 各走一次)才拿得到完整資料。

## 欄位其實存在 —— 是 walk 走不到,不是沒實作

```
snmpget .603.2.9.1.3.1.2.1  → INTEGER: 3
snmpgetnext .603.2.9.1.3.1.2 → .603.2.9.1.3.1.2.1 = 3     ← 從欄位起點是對的
```

所以 gate 報 `.1.3.1.2` missing 時,**不要當成欄位消失**。

## ⚠️ `-Cc` 不是繞道

`snmpwalk -Cc`(忽略不遞增)會無限重送同一個 OID,實測跑到 180 秒還沒停。不要用。

## 兩個連帶事實

- **委派狀態會改變 NULL 的落點**:`.1.2` 在未委派時回 10 varbinds、委派後回 9。
  比對完整性時**只比有實際值的行**,NULL 落點不可比。
- ⚠️ **「mainline 完全沒有 mxQos」是錯的,2026-08-13 同日更正。**
  mainline 對 `.603.2.9` 回的是 **`badValue`**,不是 `endOfMibView` —— 代表**有註冊、
  請求進到了 in-master handler、handler 自己回錯**(`ies_auto_mibs.c:1822` 的 fall-through)。
  `snmpwalk` 印的 `No Such Object` 是它在請求失敗後自己補的,不是 agent 說的。
  封包(`~/pcap/2026-08-13_nodelegate_*`,由 trace 3 分析)顯示實際狀態是:
  **mainline `.1.1` `.1.2` `.1.3` 都 badValue、`.1.4`–`.1.7` 正常;
  Plan E 修好了 `.1.1` `.1.2`,`.1.3` 仍壞。**
  → **mxQos 不是 Plan E 新增的覆蓋,是 Plan E 修好了 mainline 上壞掉的兩張表。**
  教訓:`badValue` 與 `endOfMibView` 分辨「handler 回錯」與「沒註冊」,
  而 snmpwalk 的 `No Such Object` 兩種情況都可能印出來。

**修這個 bug 的價值大於 `+getfwd`**:一個是客戶可見資料量 17% → 100%,
另一個是負收益(見 [[project_mxqos_forwarding_measured_slower]])。
