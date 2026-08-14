---
name: feedback-reply-in-traditional-chinese
description: "使用者要求一律用正體中文回覆,專有名詞保留原文"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7b76eced-c087-4c3e-af48-3a002d2190b4
  modified: 2026-08-11T06:20:30.666Z
---

2026-08-11 使用者明示:**「之後除了專有名詞之外,請用正體中文來回答我」**。

**Why:** 使用者的工作語言是正體中文(繁體,台灣用語),先前多輪回覆混用英文導致閱讀成本。
注意是**正體/繁體**,不是簡體。

**How to apply:**
- 所有給使用者看的文字(回覆、摘要、報告、待辦清單)一律正體中文。
- **專有名詞保留原文**,不要硬翻:OID、partition、`+getfwd`、AgentX、subagent、
  varbind、squashfs、swupdate、build、commit、pcap、MIB 欄位名、套件名
  (`plugin_moxa_snmp`)、檔名、指令。
- 技術術語若有通行中譯就用中譯(交錯量測、燒錄、封包、註冊表),沒有的就留原文。
- 這條適用於**回覆使用者**;寫給其他 session 的 SendMessage 也沿用(使用者會看到),
  但 commit message、程式碼註解、ADR 仍依各自既有慣例(多為英文)。

相關:[[feedback_verify_completeness_and_perf]]、[[feedback_dut_operation_authorization]]
