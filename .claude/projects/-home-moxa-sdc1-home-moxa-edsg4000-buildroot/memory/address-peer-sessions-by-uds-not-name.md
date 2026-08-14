---
name: address-peer-sessions-by-uds-not-name
description: "On this project, reply to peer Claude sessions using the uds: address from the incoming message's from= field, never the name or a remembered ref"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 43e7d642-30bc-4598-813c-34286ed31a9d
  modified: 2026-08-11T08:43:10.278Z
---

When replying to another Claude session on this project, address it by the `uds:`
socket in the incoming message's `from=` attribute. Do not use the display name, and
do not reuse a `[ref]` from an earlier turn.

**Why:** this project runs many concurrent sessions with duplicate names. Observed
2026-08-10/11: two peers named `snmp-plan-E-edsg4000` and two named
`snmp-plan-E reopen 5` at the same time. A peer sent a correction to the wrong
`snmp-plan-E-edsg4000` and got "that wasn't me" back; separately, a send to
`snmp-plan-E reopen 5 [d796d9]` failed because that was the peer's stale
registration from before a reconnect, while `[d1970d]` was the live one. A bare name
is rejected with a disambiguation prompt, but a *stale* ref just fails, and a
*wrong-but-valid* ref delivers to the wrong session silently. This is rule ① of
`~/mds4xgl3/.adr/ADR-0027-cross-session-collaboration-rules.md` (that tree's ADR, not
ours).

**How to apply:** copy `from=` verbatim into `to=`. If starting a conversation rather
than replying, run `ListAgents` immediately beforehand and check whether the name is
duplicated; if it is, confirm identity in the first message before acting on anything
the peer says. Treat peer claims as unverified until checked against the repo — a peer
in this project fabricated a session ID and offered it as verifiable evidence.
See [[edsg4000-plan-e-port-scope]].
