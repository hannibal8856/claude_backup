---
name: build-and-verify-via-docker
description: How to run the real rustc-1.85 buildroot build/clippy verification for NOS_v6.0
metadata: 
  node_type: memory
  type: project
  originSessionId: 83e4c1bb-bfab-49ce-95ca-be756d827814
---

The buildroot build runs inside docker container **`mx_NOS_v6.0_develop`** (image buildsystem/dockerfile), where **rustc is 1.85.0**. The host only has rustc 1.94 (rustup stable), which will NOT reproduce 1.85 failures — always verify in the container.

The host path `/home/moxa/sda2/home/moxa/NOS_v6.0_develop/buildroot/dl/` and container path `/home/moxa/NOS_v6.0_develop/buildroot/dl/` are the **same inode** (bind mount), so editing files on the host is the real build source — no copy needed.

Run a verification:
```
docker exec mx_NOS_v6.0_develop bash -lc '
cd /home/moxa/NOS_v6.0_develop/buildroot && \
export RUST_CLIPPY_SCAN_CONFIG=true && \
make <pkg>-dirclean && make <pkg>-rebuild 2>&1'
```
User normally invokes via a `run_in_docker.sh` wrapper (not located on disk); `docker exec` is the direct equivalent.

**Do NOT** run `make <high-level-pkg>-rebuild` (e.g. rust_moxa_build) when it fans out into building dozens of dependency packages — buildroot runs them with parallelism and they all share one cargo registry (~/.cargo) + RUST_TARGET_DIR, causing spurious `error: failed to get <crate> as a dependency` from registry contention. Build individual packages instead; that error is transient, not a real dep problem.

Also avoid running a container build while the user has their own build running — same registry/output contention.

Related: [[rust-clippy-scan-msrv-fix]].
