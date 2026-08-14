---
name: edsg4000-plan-e-port-scope
description: "The SNMP Plan C/D/E port to EDS-G4000 spans 13 repos on branch snmp-plan-E-edsg4000, applied as one squashed commit each"
metadata: 
  node_type: memory
  type: project
  originSessionId: 43e7d642-30bc-4598-813c-34286ed31a9d
  modified: 2026-08-11T05:24:53.908Z
---

Porting the SNMP AgentX Plan C/D/E work from the mds4xgl3 tree to
`/home/moxa/edsg4000/buildroot` spans **13 repos**. The branch to use is
**`snmp-plan-E-edsg4000`** — one squashed commit per repo, applied onto each repo's
`origin/develop` (2026-08-10, per `~/plan-CDE-package-migration-list-2026-08-10.md`).

12 dl/ repos: `app_moxa_framework` · `3rdparty_net_snmp` · `lib_moxa_ies_auto_mibs` ·
`app_moxa_iss_10_1_0` · `lib_moxa_rust_snmp_agentx` · `plugin_moxa_snmp` ·
`lib_moxa_snmp_agentx` · `lib_moxa_rust_ies_auto_mibs` · `plugin_moxa_mms` ·
`app_moxa_fiber_check` · `plugin_moxa_fiber_check` · `plugin_moxa_system_information`
— plus the **`moxa` buildroot overlay**, which is its own repo
(`general/buildsystem/moxa.git`) and carries the four AgentX package definitions,
the defconfig switches, and the net-snmp `--with-mib-modules` change adding
`agentx/master agentx/subagent`. Miss the overlay and the other 12 build nothing new.

**Why squash rather than rebase or cherry-pick:** the source branches contain revert
pairs, dead ends (`Failed`, `BACKUP`) and PoC intermediate states; replaying them
carries over designs that were already overturned. An older
`snmp-plan-E-edsg4000-mainline` branch set (full rebase) still exists in the tree —
superseded, keep but do not push.

**Two repos need care.** `lib_moxa_utility` must sit at plain `origin/develop`: its
Plan branch adds an `exec_sh_cmd_time` debug writer (`src/util_shell_cmd.c`) that costs
~15 ms per fork+exec and writes `/run` (tmpfs); the MDS removal commit landed later, so
its net diff is zero on MDS but *not* on EDS. `app_moxa_iss_10_1_0` **must** change —
ISS otherwise runs as a standalone agent that binds UDP 161 and blocks snmpd.

**How to apply:** when re-deriving scope in a sibling tree, scan exhaustively
(`for d in dl/*/` plus the overlay) for repos ahead of `origin/develop`; do not filter
on `branch == snmp-plan-E`, which misses `plugin_moxa_fiber_check`. Ignore
`app_moxa_cli` and `plugin_moxa_user_account` — unrelated to SNMP. See
[[agentx-libs-in-personal-gitlab-namespace]], [[plan-e-ab-measurement-method]] and
[[no-flash-edsg4000-swu-to-mdsg4000-dut]].
