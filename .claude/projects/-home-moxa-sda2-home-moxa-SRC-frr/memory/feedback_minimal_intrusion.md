---
name: feedback-minimal-intrusion
description: "For cross-cutting features intended to roll out across multiple daemons, minimise changes to existing code/APIs to reduce review-and-adoption friction"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5be24eb4-53d3-4f9c-9a8d-a3dbd0a52f36
---

When adding a feature (especially infra like SNMP/AgentX, logging, telemetry) that will eventually be rolled out across multiple Moxa daemons, prefer designs that **leave existing daemon code/APIs untouched**, even if a more invasive design would be more "complete" or elegant.

**Why:** User explicitly said: "改動範圍可能很難被接受; 如果能盡量維持原有的 API 架構, 新增 AgentX 的存取會讓推行的阻力更小". The first daemon's design becomes the template for every subsequent daemon — minimal-touch wins on adoption velocity even if it means a less feature-complete v1.

**How to apply:**
- Prefer **separate sibling binary** over patching the existing daemon when feasible (link against existing `lib*.so`).
- Phase the feature: v1 = read-only subset that needs zero changes; v2/v3 = add getters/setters/IPC only when the v1 pattern is accepted.
- When the cross-cutting concern truly requires touching the host daemon (e.g. trap-on-event), isolate the touchpoint to one named hook function the host daemon calls — not scattered edits.
- This applies broadly to Moxa app_* daemons under buildroot/dl/, where ownership is distributed and review cycles are long.
