---
name: project_agentx_owned_two_axis_design
description: agentx_owned.list vs iss_build are two orthogonal axes — WHICH OIDs go AgentX vs WHO serves them
metadata: 
  node_type: memory
  type: project
  originSessionId: fdcca453-327c-40cb-8faa-a4fb19df1a7f
  modified: 2026-08-07T05:16:44.578Z
---

Plan C delegation has **two orthogonal axes** (user clarified 2026-07-22):

1. **`agentx_owned.list`** (`/etc/moxa/netsnmp/agentx_owned.list`, source `plugin_moxa_snmp/app/script/`) → builds an **index table** deciding **WHICH OIDs go the AgentX route** (skip local `netsnmp_register_*`, let snmpd master longest-prefix-match route them). Currently only `ifmibdb/`.
2. **`.iss_build` per-entry flag** (in `net_*.h`) → `iss_build==1` (1391 entries, ~55 DBs), `iss_build==0` (745 entries) → reserved for later use, keep flexibility (don't hardcode ISS-only).

**CORRECTION 2026-08-07 — `iss_build` is NOT "who serves it".** The enum is
`typedef enum { BUILD_FROM_URI = 0, BUILD_FROM_ISS = 1 } build_t;`
(`snmp_tools/inc/ies_auto_mibs_handle.h:199`), and its only consumers are
`moxaSnmpHandle_UtilMibEntryCheckFromIss/FromUri`. It says **where in-master fetches
the value from** (ISS config/status layer vs URI value-file), not who answers the SNMP
request. `iss_build==1` does **not** imply ISS registers the OID over AgentX.
Counterexample: all 11 mxLa entries (`net_mxLadb.h`, `.1.3.6.1.4.1.8691.603.1.2.*`) are
`iss_build=1`, yet ISS registers nothing in that subtree — see
[[project_iss_coverage_screen_before_delegating]].

Helper already staged but **unused (0 callers)**: `moxaSnmpHandle_UtilMibEntryCheckFromIss()` / `...CheckFromUri()` at `3rdparty_net_snmp/ies-auto-mibs/moxa_snmp_handle_util.c:265,277`.

Skip insertion point: `mox_snmp_init_entry` loop, `ies_auto_mibs.c:3135`, right after `ies_auto_mibs_setup_entry_flags(entry)` → `free(entry); continue;`.

State on `2023.02.11_develop` as of 2026-07-22: list file present but **reader/skip code NOT merged yet** (`mox_snmp_entry_is_agentx_owned` absent) — user pulling it manually. Rollout = **incremental, verify ISS actually serves each DB before delegating** (else noSuchObject regression, see [[project_plan_d_two_subagent_oid_reachability]]). Evolved from RO-only skip to GET-vs-SET-mode split; SET stays on legacy ies-auto-mibs→REST→framework. Related: [[project_snmp_framework_subagent_migration]], [[project_moduri_correlates_iss_owned]].
