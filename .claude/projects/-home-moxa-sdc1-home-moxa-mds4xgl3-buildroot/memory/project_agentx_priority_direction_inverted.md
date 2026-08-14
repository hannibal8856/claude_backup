---
name: project_agentx_priority_direction_inverted
description: "framework AgentX priority=200 LOSES to in-master 127 (smaller wins) — dual-reg GET never reaches framework; Plan E's GET/SET split can't work via priority"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9f11783a-9bf6-44b6-bc6e-65aadfb575ee
  modified: 2026-07-30T10:35:52.957Z
---

**AgentX priority: smaller number wins.** RFC 2741 §6.2.3: "smaller values of
r.priority take precedence over larger values", default 127. net-snmp implements
this at `agent_registry.c:889` (`next->priority < new_sub->priority` orders the
children chain; the head serves requests).

- framework registers **200** — `lib_moxa_snmp_agentx/src/agentx.c:99/158/176`
  (comment there says "GET-serving sibling; SET stays in-master" — the intent is
  backwards from what 200 actually does).
- in-master registers **127** — `agent_handler.c:191`
  `the_reg->priority = DEFAULT_MIB_PRIORITY` (=127, `agent_registry.h:91`);
  `MOX_SNMP_INIT_ENTRY` → `netsnmp_register_handler` sets no custom priority.
  (This closes the handoff's "in-master=127 只是註解說法" unverified item.)

→ **For the 3 dual-reg groups whose in-master `MOX_SNMP_INIT_ENTRY` is still
active (mxSysTrustAccess / mxTrap / mxIpIfdb), in-master wins and framework's
IterTable handlers are dead code at runtime.** mxTurboRingV2 works only because
its INIT_ENTRY is commented out (`ies_auto_mibs_setup.c:377`).

Measured 2026-07-30, BUILD_TIME `2026_0730_1302`, DUT 192.168.127.253:
single `snmpget` → framework AgentX session packet count
`.603.3.4.1.2.1.1.1` **7** (control) / `.602.1.4.1.2.1.2.1` **0** / `.605.1.1.1.1.1.1.1` **0**.
Root-causes [[project_mxipif_col2_inmaster_deferred]] (col2 `0/0` = in-master
`atoi("vlanN")`) and answers T6 in the handoff.

**Why:** the whole ADR-0007/0008 detour started from an mxIpIf symptom that this
explains; and Plan E's "GET→framework / SET→in-master" cannot be implemented by
dual registration + priority at all — one region has exactly one winner and that
winner receives **every** PDU type (GET/GETNEXT/SET). Splitting by PDU type needs
either distinct OID regions or framework handling SET (rowStatus createAndGo/
destroy) itself.

**How to apply:** never infer AgentX ownership from walk-level packet counts — a
walk always consults the neighbouring registrant once at the region boundary
(observed floor ≈6 packets even for empty columns). Attribute with a **single
`snmpget` of one exact instance** against an idle baseline (framework's session
is silent when unqueried: 0 packets/6s; ISS's session pings ~3/6s). Identify
sessions by TCP source port from `ss -antp | grep :705`.
See [[project_snmp_walk_slow_diagnosis]], [[project_plan_e_iss0_get_forward]].
