---
name: project-dlmod-path-inventory
description: "dlmod 是第四條 SNMP 服務路徑,35 個模組,34 個純 framework、1 個純 ISS、2 個混合"
metadata: 
  node_type: memory
  type: project
  originSessionId: 29daee49-bef3-468c-b065-99511fefffc3
  modified: 2026-08-09T08:28:02.201Z
---

2026-08-09 盤點。**dlmod 是第四條服務路徑**(前三條:in-master、ISS AgentX 委派、
framework subagent),Plan E **一個都還沒搬過**
(`agentx_owned.list` 4 條全是 ISS 前綴;`g_reuse_srcs[]` 15 個全是 `net_mx_*.h` 的 MibEntry)。

## 權威判別依據

**只能看 `dlmod` 行**,從執行中的 snmpd 取:
```
tr '\0' '\n' < /proc/$(pgrep -f /bin/snmpd|head -1)/cmdline | tr ',' '\n' | grep '\.conf$'
→ 逐檔 grep '^[[:space:]]*dlmod'
```
MDS-G4000-L3-4XGS `2026_0808_1743` 實測 **35 個**,且 `/moxa/run/snmp/snmpd.conf` 有 **0** 行
(所以 `/etc/moxa/netsnmp/config/` 就是完整集合)。**數量隨產品不同**。

⚠️ **兩個會假陽性的指標,都踩過:**
- **「repo 底下有沒有 `snmp/` 資料夾」不可用。** `plugin_moxa_system_information` 用的是
  `snmp_config/` + `snmp_status/`,掃 `snmp/` 會漏掉它;而 `plugin_moxa_email` /
  `plugin_moxa_trusted_access` / `plugin_moxa_arp_table` **有** `snmp/` 卻**不是 dlmod**
  —— email 與 trustAccess 早就在 `g_reuse_srcs[]` 裡(已搬到 framework),
  留著 `snmp/` 只是舊碼沒清。列進待搬清單會重複工。
- 用 `.so` 檔名或目錄名推 feature 名也不可靠(`mxgoosecheck` →
  `plugin_snmp_moxa_goose_check.so`)。

## 最終目的地(binary 層面分類,避開原始碼目錄命名)

```
uri=$(strings $so | grep -cE '^/api/v1/')
iss=$(nm -D --undefined-only $so | grep -ciE 'IssTable|_iss_')
```

| 判定 | 數量 | 誰 |
|---|---|---|
| **純 framework** | 34 | 其餘全部(poe 51 URI 最大) |
| **混合** | 2 | `ieee8021mstp`(13 URI + 4 ISS)、`moxa_goose_check`(7 URI + 3 ISS) |
| **純 ISS** | **1** | **`multicast_routing`**(0 URI + 3 ISS) |

## `multicast_routing` —— 架構上最有意思,但目前表是空的

- 唯一純 ISS 的 dlmod
- **ISS 已經宣告它的 OID**:`code/future/mri/inc/mxMRdb.h`,root `.1.3.6.1.4.1.8691.605.4.1`
- `code/future/mri` 有 **8 個 `.o` → 有編**,ADR-0019 的 gate 1 過關
- → 它是 **ISS AgentX 委派**(`agentx_owned.list`)的候選,不是 framework 搬遷的候選。
  委派正是給出 mxrstpdb 47 倍的那個機制。
- ⚠️ **但實測 walk 只有 1 個 varbind、0.073s —— 功能沒啟用、表是空的。**
  要展示效益必須先用 moxash 把功能開起來填資料(見 [[reference-moxa-cli-manuals]])。

## 搬遷需要什麼

dlmod 的 SNMP↔URI 對應**寫死在各 plugin 自己的 C 碼**(如
`plugin_snmp_poe.c` 67.9K 內含 `/api/v1/setting/agent/mxPoeAgent/...`),
ies-auto-mibs 底下**沒有**任何 dlmod feature 的 `net_*.h`。
→ 搬到 framework 要**額外建立 `net_mx_<feature>.h`**,把 OID↔URI↔型別↔access
寫成 `ies_auto_mibs_entry` 陣列再加進 `g_reuse_srcs[]`。這些對應分散在各 feature 自己的 repo。

**尚未驗證(動手前必做)**:dlmod 的「退出」機制。推測是拿掉 `.conf` 的 `dlmod` 行
(比 in-master 註解 `MOX_SNMP_INIT_ENTRY` 乾淨),但 dlmod 與 AgentX 的**優先權行為沒實測過**,
不能假設同 in-master 的 127 vs 200。

相關:[[project-snmp-framework-subagent-migration]]、[[project-iss-coverage-screen-before-delegating]]、
[[project-registration-count-hypothesis-refuted]]。
