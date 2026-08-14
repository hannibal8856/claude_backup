---
name: user-verifies-builds-himself
description: "User runs the buildroot make verification himself — don't run make rebuild to verify fixes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 06089eea-89b1-4ba6-91e6-624dca2bad18
---

After applying a fix to rust/buildroot packages, do NOT run `make <pkg>-dirclean/rebuild` (in docker or otherwise) to verify — the user runs the build himself and pastes the result back.

**Why:** stated 2026-06-10 ("之後請不需要驗證, 我來就可以了"); also avoids cargo-registry/output contention with his running builds (see [[build-and-verify-via-docker]]).

**How to apply:** still fine to run cheap read-only inspection (grep/ls, `cargo info`, lockfile checks) and resolution-only commands needed to *produce* the fix (e.g. `cargo generate-lockfile`/`cargo update --precise` in the container build tree) — just stop before the actual build/clippy run and hand off.
