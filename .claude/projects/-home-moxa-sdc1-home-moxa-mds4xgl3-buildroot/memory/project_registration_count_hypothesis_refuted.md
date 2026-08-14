---
name: project-registration-count-hypothesis-refuted
description: "「in-master 註冊表縮小讓未搬遷 group 變快」已被對照實驗推翻,簡報不可這樣歸因"
metadata: 
  node_type: memory
  type: project
  originSessionId: 29daee49-bef3-468c-b065-99511fefffc3
  modified: 2026-08-09T04:10:26.816Z
---

2026-08-09 用單一變數 A/B 對照實驗(ADR-0018)**推翻**了一個曾被當成主要歸因的推論。

**被推翻的說法**:Plan E 從 in-master 移走約 710 筆註冊,使 net-snmp 的 subtree 串列
變短、每次 GETNEXT 變便宜,所以連 `stdvladb/` `stdcipdb/` `stdospdb/` 這種
**完全沒搬遷**的 group 也快 38–66%。

**實驗**:同一棵原始碼、同一次 build,只差 `ies_auto_mibs_setup.c` 那 13 行
`MOX_SNMP_INIT_ENTRY` 註解,產出兩顆 `libnetsnmpmibs.so`,bind mount 輪流掛上同一台
執行中的 DUT(squashfs 唯讀,bind mount 是唯一途徑;重開機自動還原,p1/p2 未寫入)。

**結果**:還原 597 筆註冊 → 三個 group 完全沒變(A→B→A 交錯,±2% 內)。
而 B 的註冊**確實生效**:`evtPort` 1.379s → **37.355s**(慢 27×)、欄位 73 → 62;
`mxTurboRingV2` 0.141s → 1.248s、欄位 17 → 15。所以是真陰性不是偽陰性。

**How to apply:**
- outline CIC 簡報**不可**寫「搬走 710 筆註冊讓整台機器都受惠」。那三個 group 的加速
  **原因未知**,只陳述現象、不歸因。
- 但這個實驗給了一個**更好用的正向素材**:把 `evtPort` 從 framework 收回 in-master
  慢 27 倍,是在**同一台機器、同一顆 image、只差 13 行**下量到的,比跨 image 對照更難反駁。
- 若要續查那 38–66%,第一步是**回 p2 重新交錯量一次 mainline**,先確認現象重現得出來
  —— 原本那組 mainline 數字不是與 planE 交錯量的。

**Why:** 這個歸因原本要寫進對外簡報,一旦被問「`stdvladb/` 有走 AgentX 嗎」就會破功。

相關:[[project-ies-auto-mibs-setup-no-dep-tracking]](這個實驗差點因為它得到偽陰性)、
[[project-pysnmp-shadows-snmpwalk]](量測管線陷阱)、
[[project-snmp-framework-subagent-migration]]。
