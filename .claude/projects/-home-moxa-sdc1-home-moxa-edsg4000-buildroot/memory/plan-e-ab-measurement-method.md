---
name: plan-e-ab-measurement-method
description: "How to measure Plan E effects on the EDS-G4000 rig — single-variable A/B via bind-mounted .so, and the md5 check that prevents a false negative"
metadata: 
  node_type: memory
  type: project
  originSessionId: 43e7d642-30bc-4598-813c-34286ed31a9d
  modified: 2026-08-13T05:56:45.607Z
---

When the EDS-G4000 rig is available and Plan E effects need measuring, do **not**
compare two separately-built images — that carries too many confounding variables.

**Method:** produce two `libnetsnmpmibs.so` from the *same* build, bind-mount them onto
the DUT in turn, and interleave **A→B→A** to confirm reproducibility.

**The trap that produces a false negative:** `3rdparty_net_snmp` has dependency tracking
disabled (no `.deps`/`.Plo`/`.d` under its build tree), and `ies_auto_mibs_setup.c` is
`#include`d into `ies_auto_mibs.c` rather than compiled separately. Changing only
`ies_auto_mibs_setup.c` and rebuilding yields a **byte-identical `.so` with no error**.
`snmp-plan-E reopen 4` hit exactly this on their first A/B run — both `.so` had the same
md5. Fix: `touch ies_auto_mibs.c`, delete the stale `.o`/`.lo`, and **compare md5 of the
file actually on the DUT** against the one you intended, every single run.

**Second trap, confirmed live on this host:** `command -v snmpwalk` resolves to
`/home/moxa/.local/bin/snmpwalk` (pysnmp), which shadows `/usr/bin/snmpwalk`. It returns
0 varbinds and looks exactly like a hung snmpd on the DUT. `snmpgetnext` is not shadowed.
Always use the absolute path `/usr/bin/snmpwalk`.

**`+getfwd`: verify it on the EDS rig yourself; do not inherit the MDS answer.** Which
prefixes actually forward has been asserted and retracted repeatedly on the MDS side —
ADR-0014 was read as a result when it was only a requirement; ADR-0025 (2026-08-10)
claimed the flag was *silently inert* on `mxportdb/`/`stdethdb/`; ADR-0028 (08-11) said
only `mxrstpdb/` had packet evidence; ADR-0030 (08-12) then overturned both, showing all
four prefixes (`ifmibdb/` `stdethdb/` `mxportdb/` `mxrstpdb/`) forwarding, with five
AgentX Get PDUs decoded to `ISS.exe`. **Why the earlier runs showed nothing was never
explained** — the old script and pcaps no longer exist, leaving one unproven hypothesis
(a bad `fwdcheck.sh` criterion). Treat the current answer as the best available, not as
settled, and re-derive it on EDS hardware rather than citing any ADR number.

**Trust `fwdcheck.sh` asymmetrically — it is the prime suspect for the earlier false
negative.** The one surviving hypothesis for why 2026-08-10 saw no forwarding is a bad
criterion in the *old* `fwdcheck.sh`; that version no longer exists, so whether the
current one inherits the same defect is **unknown**. Therefore: a result of **"forwards"
is credible** (a false positive would require the tool to invent AgentX PDUs), while a
result of **"does not forward" is not a conclusion** — before believing it, confirm the
negative control actually produced a negative and the positive control actually produced
a positive. Write this into the read-out rule, not just general experimental hygiene.

**`walkpcap.sh` has a confirmed capture bug that hands you a silent empty pcap.** Line 40
uses `tcpdump ... -G $DUR -W 1`. The failure is real and reproduced; the *mechanism* is
not established — "`-G` rotates on absolute wall-clock multiples so starting near a
boundary truncates the window" is only a hypothesis, and the evidence points the other
way: two captures 20 minutes apart with `-G 25` both died in under 1 second
("Maximum file limit reached: 1"), which random boundary placement would produce about
0.6% of the time. Deterministic failure (e.g. start time never initialised, so the first
rotation check fires immediately) fits better. **Practical consequence: never treat a
re-run as the workaround.** If it is deterministic, re-running just hands you a second
empty capture that reads as a genuine negative. Switch to the `kill -INT` pattern below
unconditionally.
`snmp-plan-E reopen 7` hit this twice on 2026-08-13: stderr read a perfectly normal
"19 packets captured / 42 received by filter / 0 dropped", the pcap was 1.7 KB of
background keepalive with **zero Get/GetNext** — and zero Get PDUs is exactly what "no
forwarding" predicts. Recapturing correctly gave 70 KB / 201 GetNext from the same OID and
image. Working pattern: record the tcpdump PID in the same session and `kill -INT` it, plus
three self-checks — `kill -0 $TP` right as the walk begins, report the walk's varbind count
to prove it ran, and `ps | grep -c tcpdump` afterwards to prove nothing lingers. Drop any
one and an empty capture reads as a result. Note the **DUT has no `timeout` command**
(`exit 127`), so `timeout N tcpdump` cannot be used to bound it.

Three known defects in `measure-snmp-walk` (per `snmp-plan-E reopen 7`, 2026-08-13):
`DUR` does not scale with `N`, so **small samples fabricate `delta=0`** — never sweep
several prefixes at low `N` and conclude "no difference"; `cnt()` re-reads the whole pcap
each call, so large captures look like a hang; and `dutssh.exp` hung for 11 hours on
their host (`timeout 90` did not fire, stuck after `pkill -INT tcpdump`). Do not assume
`timeout` will save you, and verify tcpdump is actually dead on the DUT afterwards — a
leftover capture contaminates the next verdict.

**The stable part — "does it forward" and "is it faster" are separate questions.** Real
forwarding is expected to produce **no measurable walk-time change**: the once-claimed
0.66s → 0.63s gain on mxRstp was retracted as smaller than A↔A2 repeatability
(0.022–0.033s). A clear speedup is a reason to suspect the method, not to celebrate.
Use `measure-snmp-walk`'s `fwdcheck.sh` (pcap, mandatory positive+negative controls) for
the first question and interleaved `walk.sh` for the second.

**Triage by local read cost before spending rig time on any A/B.** Measure the group's
in-master cost in **ms/varbind** first. If the local read path is already fast, that alone
is sufficient reason not to delegate — no A/B needed, because ISS's cost to answer cannot
be beaten. `mxQos` in-master was 2.98 ms/varbind and delegating lost. So: rank candidates
by local ms/varbind and run full A/B only on the slow ones.

**Ask whether delegation is net-positive at all — it is not always.** On MDS, `mxQos`
measured **14% slower** when forwarded (A in-master 1.4033/1.4117s vs B +getfwd
1.5960/1.6144s, repeatability 0.008/0.018s, controls valid at 2 vs 201 GetNext), so it was
not migrated. This is structurally surprising: in-master goes through LibFrameworkUri and
**rebuilds a TCP connection per request** while AgentX holds a persistent one, so in-master
"should" lose — meaning the ISS side's cost to answer exceeds local connect+read. Wherever
the local read path is already fast, delegating to ISS is **negative value**. EDS runs a
different chip family (Broadcom vs Marvell), so the relative costs may not carry over in
either direction; treat MDS verdicts as priority hints, never as permission to skip
measuring.

**Why this matters:** as of 2026-08-10 the "registry shrinkage" explanation for Plan E's
speedup was **disproven** by a single-variable A/B (ADR-0018) — restoring 597 in-master
registrations changed nothing. Only two effects have direct evidence: ISS delegation
(`mxrstpdb/` 31.0s → 0.658s) and framework migration (pulling `evtPort` back to in-master
costs 27x: 1.379s → 37.355s). Do not predict EDS gains from registry size.
See [[edsg4000-plan-e-port-scope]].
