---
name: project_agentx_owned_list_parser_landmine
description: "agentx_owned.list 的 loader 行 buffer 曾等於 prefix 長度(64),長註解被 fgets 切半後續行變成假 prefix;已於 e605314 修好,但改這個檔前要知道"
metadata: 
  node_type: memory
  type: project
  originSessionId: d3f32579-7f66-464a-b856-526a67163a15
  modified: 2026-08-08T01:45:41.738Z
---

`mox_snmp_load_agentx_owned_list()`(`3rdparty_net_snmp/ies-auto-mibs/ies_auto_mibs.c`)
原本用 `char line[AGENTX_OWNED_PREFIX_LEN]`(64)讀檔,但 `agentx_owned.list`
的**註解行大多超過 63 字元**。`fgets` 把長行切兩半,**續行會被當成新的 prefix 條目**。

2026-08-08 實測:已 commit 的檔案解析出 **19 條,其中 16 條是垃圾**
(`n`、`er`、`is`、`or`、`pty`、`ted.`…)。這 16 條剛好都沒撞到全樹 45 個真實
URI 模組前綴,所以 DUT 行為一直正確 —— **純屬運氣,不是設計**。

危險在於 prefix 比對是 `strncmp(entry->uri, prefix, strlen(prefix))`,
**短垃圾字串會大範圍命中**。當時為了說明 `+getfwd` 加註解,生出 prefix `s`,
命中全部 17 個 `std*db/` 模組 —— 會把它們的 RO entry 全部誤委派出去。

已在 commit `e605314` 修掉:拆出獨立的 `AGENTX_OWNED_LINE_LEN`(256),
並在讀到超長行時把尾巴吞掉,只有行首能成為條目。

**還是要記得的兩件事:**
- `AGENTX_OWNED_MAX` 是 32。修好之前註解已吃掉 19 格;現在只算真 prefix,
  但這個上限仍在。
- **改完 list 或 loader,先在 host 端用獨立小程式跑一次 parser 再 build** ——
  這個 bug 是靠 host 端 parser 測試發現的,build 不會報任何錯。

相關:[[project_snmp_framework_subagent_migration]]、[[feedback_verify_completeness_and_perf]]
