---
name: iss-agentx-subagent-161-conflict
description: Why ISS AgentX-enable crashed snmpd (standalone agent binds UDP 161) and the exact fix (disable snmpagent + enable snmpsubagent master 127.0.0.1:705)
metadata: 
  node_type: memory
  type: project
  originSessionId: f799ca36-ae55-4954-a42d-21c79180a90b
---

Plan C PoC (AgentX): enabling ISS SNMP the naive way crashes net-snmp snmpd in a restart loop.

**Root cause (confirmed 2026-06-23 by branch bisection + manual):** ISS `snmp-trace-time_diff-3` branch enabled `SNMP_2_WANTED`/`SNMP_3_WANTED` in `app_moxa_iss_10_1_0/code/future/LR/myconfig.h`, which brings ISS up as a **standalone SNMP agent** (default mode `SNX_SNMP_ACTIVE_AGENT`, see `code/future/inc/fssnmp.h`). A standalone agent **binds UDP 161** — the same port net-snmp snmpd owns — so snmpd loses the bind and exits status 1, restart-looping (`app_moxa_snmp_server.service`, ExecStart `/etc/moxa/config-moxa-snmp/init_snmpd.sh` → `/bin/snmpd -f -C -c <conf-list>`). ISS `develop` has these flags off, so it doesn't crash.

ISS SNMP has two **mutually exclusive** modes (`fssnmp.h`): `SNX_SNMP_ACTIVE_AGENT` (standalone, binds 161) vs `SNX_AGENTX_SUBAGENT` (subagent, connects out to master, binds nothing). Manual ISSCLIum-Vol1 §11.1.1: `enable snmpsubagent` "executes only if snmp agent is disabled"; §11.1.3: SNMP agent enabled by default; AgentX master port default = 705.

**The fix (verified working — snmpd stable, 705 session ESTABLISHED, 161 only snmpd):**
```
# ISS CLI (telnet localhost:6023):
disable snmpagent
enable snmpsubagent master ip4 127.0.0.1 port 705
copy running-config startup-config
```
snmpd side = change B (`master agentx` + `agentXSocket tcp:127.0.0.1:705` in config_moxa_snmp_control.c). Subagent CONNECTS to master:705 (does NOT bind 705 or 161). Persists to **startup-config**, NOT `issnvram.txt` (issnvram.txt = early-boot params: default VLAN/bridge mode/MAC/SNMP engine id only).

**Still unverified:** reboot survival — whether startup-config's `disable snmpagent` applies before ISS binds 161 at boot. If snmpd crash-loops briefly after reboot, the 161 bind happens before config-restore → must change init default (don't enable snmpagent by default) instead of relying on startup-config. See [[build-order]] and the Plan C design at ~/plan-c-agentx-poc-design-2026-06-12.md.
