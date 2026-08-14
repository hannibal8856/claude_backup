---
name: project-agentx-probe-max-128-silent-overflow
description: "AGENTX_PROBE_MAX=128,probe 候選滿了就靜默丟棄;再開一個大 group 就會溢出,症狀跟 ADR-0025 未解的 bug 一模一樣"
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-12T06:59:16.345Z
---

`ies_auto_mibs.c:3098` `#define AGENTX_PROBE_MAX (128)`,而
`mox_snmp_probe_note_delegated()`(`:3120-3124`)在滿了之後**直接 return,不記錄也不報錯**。

目前四個 prefix 全開 `+getfwd` 的候選數(2026-08-12 由 `net_*.h` 解析):

| prefix | RW | probe 候選 | 未 shadowed |
|---|---:|---:|---:|
| ifmibdb/ | 7 | 40 | 40 |
| stdethdb/ | 1 | 33 | 33 |
| mxportdb/ | 8 | 9 | 7(PortConfigIndex、PortConfigLinkUpDelayIndex 被合成 index 欄搶走)|
| mxrstpdb/ | 9 | 18 | 18 |

合計 **100**,尚未滿。**但 `stdrmodb/` 光 RO 就有 104 個** —— 加進去是 204,
**76 個候選被無聲丟棄**,丟的是註冊順序在後面的那些。

**Why:** 溢出後的症狀是「乾淨的 fall-through」—— 值與型別全對、walk 正常、就是沒有
AgentX 流量,**跟 [[project_getfwd_noop_on_mxportdb_stdethdb]](ADR-0025)那個還沒定位的
bug 長得一模一樣**。屆時很容易把新的溢出問題誤判成舊 bug 的延伸,查錯方向。

**How to apply:** 在 `agentx_owned.list` 新增帶 `+getfwd` 的 prefix 前,先算該 prefix 的
RO entry 數,累加後不得超過 128;超過就要先把 `AGENTX_PROBE_MAX` 調大。
注意 **probe 只在 prefix 有 `+getfwd` 時才會被記錄**(`:3557-3560`),所以只做 RO 委派
(不標旗標)的 prefix 不佔額度。驗證仍須照 [[project_getfwd_probe_must_be_wire_verified]]
用 pcap 判定,不能只看 walk 時間。
