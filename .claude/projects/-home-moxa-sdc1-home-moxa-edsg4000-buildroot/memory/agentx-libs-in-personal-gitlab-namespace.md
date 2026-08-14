---
name: agentx-libs-in-personal-gitlab-namespace
description: The four AgentX library repos only exist under a personal GitLab namespace; their Config.in default URLs point at general/ paths that do not exist
metadata: 
  node_type: memory
  type: project
  originSessionId: 43e7d642-30bc-4598-813c-34286ed31a9d
  modified: 2026-08-09T03:43:57.825Z
---

The four Plan E AgentX library packages — `lib_moxa_snmp_agentx`,
`lib_moxa_rust_snmp_agentx`, `lib_moxa_ies_auto_mibs`, `lib_moxa_rust_ies_auto_mibs` —
exist **only** at
`git@gitlab.com:moxa/sw/switch/personal/oscarmh.tu.switch/<pkg>.git`.

Their `Config.in` files in the `moxa` overlay repo ship a default `_URL` of
`git@gitlab.com:moxa/sw/switch/general/linuxframework/library/<pkg>.git`. Verified
2026-08-09 with `git ls-remote`: **all four `general/` URLs do not exist** (or are not
readable). Only the personal-namespace URLs resolve.

**Why:** a clean `install.sh` / repo-sync run on the EDS-G4000 tree using the shipped
Config.in defaults silently fails to fetch these four packages, and they are also absent
from the EDS `moxa/package/net/` tree on `develop` — so the failure looks like "package
doesn't exist" rather than "wrong URL".

**How to apply:** on branch `snmp-plan-E-edsg4000-mainline` in the `moxa` overlay repo,
the four `Config.in` `_URL` defaults were repointed at the personal namespace (user
approved 2026-08-09) so EDS can build. This is a stopgap — depending on a personal
namespace blocks real mainlining, and moving the repos to `general/` is an
organizational decision for the user and the repo owner, not something to patch around
further. See [[edsg4000-plan-e-port-scope]].
