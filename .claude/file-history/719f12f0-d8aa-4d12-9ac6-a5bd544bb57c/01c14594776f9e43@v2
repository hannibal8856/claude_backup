---
name: mxipif-col2-inmaster-deferred
description: "mxIpIf ifVlanId (col2) walks as 0/0 = in-master serving/shadowing; user deferred (in-master issue, not framework)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 719f12f0-d8aa-4d12-9ac6-a5bd544bb57c
  modified: 2026-07-28T10:50:44.188Z
---

mxIpIf `ipifConfigIfMainTable` col2 (ifVlanId), OID `.1.3.6.1.4.1.8691.605.1.1.1.1.1.2.<row>`, snmpwalks as **0 / 0** for the two interfaces (ifName `vlan1`, `vlan222`) on DUT 192.168.127.253 (observed 2026-07-28, image BUILD_TIME 2026_0728_1732).

`0` is the **in-master** rendering: net-snmp does `atoi("vlanN")` → 0 because the leading 'v' is non-numeric. The framework's `l3vlanif_iter_handler` (snmp_subagent.rs col2) instead strips `"vlan"` and parses → would render **1 / 222**. So col2==0 is the litmus that **in-master is serving/shadowing mxIpIf GET**, not the framework.

**User decision (2026-07-28): this is an in-master problem — DEFER, do not fix now. Just recorded.**

**Why:** even with ADR-0007 config-half in place (framework reads config via REST), the `.605.1.1.1.1` subtree is still answered by in-master (in-master registration wins / shadows the framework's table_iterator). Fixing col2 means getting the framework to take over the column, which is the ISS/in-master shadow problem, not a framework-side bug.

**How to apply:** when re-verifying mxIpIf after a framework rebuild, col2 flipping `0→1/222` is the signal the framework took over; while it stays `0/0`, in-master is still serving and the fix belongs on the in-master side (deferred). Do not chase this as a framework config-read bug. Related: [[project_moduri_correlates_iss_owned]], [[project_plan_e_iss0_get_forward]], [[project_plan_d_two_subagent_oid_reachability]].
