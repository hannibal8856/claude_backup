---
name: feedback_context_60_reminder
description: "User wants a proactive heads-up when context usage approaches 60%, every session"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fdcca453-327c-40cb-8faa-a4fb19df1a7f
  modified: 2026-07-23T17:28:56.126Z
---

Proactively warn the user when context usage approaches ~60% — in **every** session, not just when asked.

**Why:** This project's sessions get very long (deep multi-turn design/debug, e.g. the Plan E SNMP work). The user wants a natural checkpoint to decide whether to hand off (session-to-doc) or keep going before context gets tight.

**How to apply:** Estimate from conversation length + accumulated tool output (no precise live % readout exists — say so). When you judge it near 60%, mention it once and offer a handoff option (session-to-doc + memory). Don't spam it every turn after; one heads-up around the threshold is enough. `/context` is the precise tool if they want exact numbers.
