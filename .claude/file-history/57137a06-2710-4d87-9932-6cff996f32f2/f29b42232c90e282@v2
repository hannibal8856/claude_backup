---
name: f1-branch-isolation
description: All F1 tree changes go on branch snmp-plan-F1; never commit onto snmp-plan-E.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 57137a06-2710-4d87-9932-6cff996f32f2
  modified: 2026-08-13T09:54:15.539Z
---

User instruction (2026-08-13): in the `SNMP_PLAN_F1/buildroot` tree, any change must
be made on a branch named `snmp-plan-F1`. Do not modify or commit onto `snmp-plan-E`.

On 2026-08-13 `snmp-plan-F1` was created (at the then-current `origin/snmp-plan-E`
commit) in 10 repos: `moxa/` plus `dl/` packages `3rdparty_net_snmp`,
`app_moxa_fiber_check`, `app_moxa_framework`, `app_moxa_iss_10_1_0`,
`lib_moxa_utility`, `plugin_moxa_fiber_check`, `plugin_moxa_mms`, `plugin_moxa_snmp`,
`plugin_moxa_system_information`.

**Why:** Plan E is a live parallel effort owned by another session working from
`~/mds4xgl3`. F1 shares the same upstream package repos, so a commit landing on
`snmp-plan-E` from this tree would silently alter their work.

**How to apply:** before editing any package in this tree, check the current branch
(`git -C <pkg> rev-parse --abbrev-ref HEAD`) and create/switch to `snmp-plan-F1`
if it is not already there. Note that `moxa/fetch_source.sh:157` checks out
`origin/<REV>`, which re-detaches the `dl/` packages back off `snmp-plan-F1` on
every run — re-verify the branch after any fetch. `moxa/` itself is not a fetched
package and keeps its branch. Verify branch state with python or `rtk proxy`, not
plain git through the hook — see [[rtk-fabricates-ls-output]].
