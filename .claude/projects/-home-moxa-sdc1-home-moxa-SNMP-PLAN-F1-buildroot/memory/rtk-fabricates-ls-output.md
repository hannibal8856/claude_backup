---
name: rtk-fabricates-ls-output
description: The rtk Bash hook can return directory listings containing entries that do not exist; verify filesystem claims with unfiltered commands.
metadata: 
  node_type: memory
  type: project
  originSessionId: 57137a06-2710-4d87-9932-6cff996f32f2
  modified: 2026-08-13T09:12:14.340Z
---

On 2026-08-13, in `SNMP_PLAN_F1/buildroot/dl`, a hook-rewritten `ls -d lib_moxa_*`
returned `lib_moxa_ies_auto_mibs/`, `lib_moxa_rust_ies_auto_mibs/` and
`lib_moxa_rust_snmp_agentx/`. None of those directories exist. Three unfiltered
checks agreed they were absent: `test -d`, pure shell glob expansion, and
`rtk proxy ls -1`. rtk also normalizes output in other ways (appends trailing `/`,
replaces empty `git status --porcelain` with `ok`, collapses grep output into a
"N matches in M files" summary with mangled line prefixes).

**Why:** a fabricated-but-plausible listing is exactly the silent failure mode that
wastes hours — it makes an absent package look present, or an empty result look
like a real one.

**How to apply:** for any claim of the form "file/dir X exists" or "X does not
exist", confirm with `rtk proxy <cmd>`, `test -d`/`test -f`, shell glob expansion,
or the Read/Glob tools — never on hook-rewritten `ls`/`grep` output alone. Same
rule for counts. See the Plan E discipline in [[plan-e-tooling-hazards]].
