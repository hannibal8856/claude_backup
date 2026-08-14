---
name: no-flash-edsg4000-swu-to-mdsg4000-dut
description: Never upload/flash EDS-G4000 .swu builds to the attached DUT — the serial DUT is a different model (MDS-G4000-L3)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 43e7d642-30bc-4598-813c-34286ed31a9d
  modified: 2026-08-09T01:25:33.862Z
---

EDS-G4000 `.swu` firmware built in this tree must **not** be uploaded or flashed to
the DUT on `/dev/ttyS0`. Stated by the user on 2026-08-09: "不要upload到DUT! 機種不同
環境我架好以後會再通知你" — they will set up a matching EDS-G4000 rig and notify me
when it's ready.

**Why:** the serial DUT wired to this host is an MDS-G4000-L3-4XGS. Flashing an
EDS-G4000 image onto it is a cross-model flash and can brick the unit. The
`examinate-plan-e-swu` skill targets that MDS DUT by default, so invoking it after an
EDS-G4000 build would do exactly the wrong thing.

**How to apply:** after an EDS-G4000 build, report only the `.swu` path, size, and
timestamp. Do not scp, do not run `swupdate`, do not invoke `examinate-plan-e-swu` or
`dut-console` for flashing. Wait for the user to confirm the correct EDS-G4000
environment is up before any device-side step.
