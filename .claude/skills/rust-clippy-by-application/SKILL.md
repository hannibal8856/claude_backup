---
name: rust-clippy-by-application
description: Use when MXNOS/buildroot Rust clippy scan fails under a pinned rustc (e.g. rustc 1.85, "rustc 1.85.0 is not supported", icu_*/bytestring/actix needing 1.86/1.88) because packages re-resolve crates without a Cargo.lock; or when converting per-package clippy scanning to per-application; or rolling out the per-package GitLab issue+branch+MR changes across many dl repos.
---

# Rust Clippy: by-package → by-application

## Overview

In MXNOS/buildroot, `RUST_CLIPPY_SCAN_CONFIG=true` makes each Rust package run its own `cargo clippy`. A **library** scanned standalone has no `Cargo.lock`, so cargo re-resolves to latest crates → newer rustc required → scan fails under pinned rustc 1.85 (normal build passes because it uses the app's lock).

**Core fix:** stop scanning libraries standalone. Scan only **applications (BIN crates)**, and make each app lint its whole local dependency closure via `RUSTC_WRAPPER=clippy-driver cargo check`. The app's `Cargo.lock` then governs all its libraries (no re-resolution), and the libs are linted with the app's real `--features`.

**Why `clippy-driver`, not `cargo clippy`:** `cargo clippy` only lints workspace members (`RUSTC_WORKSPACE_WRAPPER`); `cargo clippy -p <path-dep>` prints `Checking` but does NOT run clippy on it. MXNOS libs are path deps in scattered `*-custom` dirs (not members), so the only way to lint them is `RUSTC_WRAPPER=clippy-driver` — it applies clippy-driver to EVERY compiled crate. crates.io deps are silenced by cargo's automatic `--cap-lints allow`, so only local libs surface.

## When to use
- Clippy scan fails under pinned rustc but `make <pkg>-rebuild` (build only) passes.
- Bringing a new product branch's Rust packages onto by-application scanning.
- Need to mass-create issue+branch+MR for the resulting per-package changes.

## Step 1 — Classify app vs lib

A package is an **application (BIN)** if its dir has `src/main.rs`, `src/bin/`, or `[[bin]]` in Cargo.toml; otherwise it's a **library**.

```bash
cd buildroot/dl
find . -maxdepth 4 -name Cargo.toml -not -path '*/target/*' | while read m; do d=$(dirname "$m");
  { [ -f "$d/src/main.rs" ] || [ -d "$d/src/bin" ] || grep -q '^\[\[bin\]\]' "$m"; } && echo "BIN $d"; done
```
(MXNOS NOS_v6.0: ~19 BIN repos / 22 crates, ~156 libs. Note depth-4 catches `3rdparty_net_snmp/snmp_script_rust/<bin>` and `plugin_*/app`.)

## Step 2 — dl Makefile changes

**App** `rust_clippy_scan` — convert `cargo clippy ... --target-dir=$RUST_TARGET_DIR [--features ...]` to:
```
RUSTC_WRAPPER=clippy-driver cargo check --release --target=${TARGET} --target-dir=${RUST_TARGET_DIR} [--features ${CARGO_FEATURES}]
```
(both the plain line and the `--message-format=json > rust_clippy_scan_result/<name>.json` line). For plugins with an app+framework split, keep the `app` scan, **remove the `framework` scan lines**.

**Library** — remove the whole `rust_clippy_scan:` block and unhook it from `all:` (`all: rust_clippy_scan` → `all:`). Each dl repo is its own git repo; commit "clippy scan binaries only".

## Step 3 — ${moxa} (buildsystem/moxa) `.mk` changes

For each **library** `moxa/package/net/<pkg>/<pkg>.mk`:
- Remove the `@if [ "${RUST_CLIPPY_SCAN_CONFIG}" = "true" ]; … cp -rf $(@D)/rust_clippy_scan_result … fi` block.
- Remove `RUST_TARGET_DIR=$(BR2_MOXA_RUST_TARGET_DIR)` from the BUILD_CMDS line (its only consumer was the scan).
- **Keep both** for the 19 app `.mk` (the app scan still uses them).

Buildroot derives pkgname from the **directory** and includes `.mk` by `wildcard`, so a misnamed `.mk` still works but breaks tooling — flag it, don't rely on it.

## Step 4 — post-build.sh gate

`moxa/board/net/common/post-build.sh` clippy check should be:
1. Hard gate: every `.mk` that still exports `rust_clippy_scan_result` (= the apps, derived dynamically) must produce its json.
2. Informational only: a Rust lib not referenced by any application prints a `Note:` (no exempt list, no failure — lib 依附 app,沒被掃不是錯). Match coverage via both `<pkg>-custom` (path deps) and `/<pkg>#` (symlink workspace members like rust_moxa_build).
Also initialise `exit_code=0` before the `check_rust_pkg_br_dependency.py` call.

## Step 5 — verify (canary)

Append a warn-level lint to a lib's `src/lib.rs` (or `framework/src/lib.rs`), rebuild that lib, run an app scan, expect the warning attributed to that lib; restore. `cargo check`/`build` do NOT report it — only clippy does, which proves clippy actually ran.
```rust
pub fn clippy_scan_canary() { return; }   // triggers warn-level clippy::needless_return
```
Coverage is **feature/config-dependent**: a package that is a dummy (not built) in one product won't be scanned there (e.g. export_cli_submode_interface_vlan: absent in L2, present in L3). Verify on the same defconfig the build uses; gotcha: shared `RUST_TARGET_DIR` caches a no-lint check — `touch` the lib src to force re-lint.

## Step 6 — sync app Cargo.lock (build → dl)

Before rolling out MRs, verify each **application's** committed lock is current. If a path-dependency's Cargo.toml gained deps, cargo does incremental re-resolution at build time and rewrites the lock in `output/build/<pkg>-custom/`, which never flows back to `dl/`. A stale committed `dl/<pkg>/.../Cargo.lock` means every clean build re-resolves to *latest-compatible* (connects to crates.io, non-reproducible, risks the MSRV failure returning).

```bash
scripts/check_rust_app_lock.sh <buildroot>   # exit 1 if any app's dl ≠ output/build lock
# for each drifted app: cp output/build/<pkg>-custom/.../Cargo.lock  dl/<pkg>/.../Cargo.lock ; commit "Synchonize Cargo.lock"
```
Tell-tale of a stale lock in the build log: `Updating crates.io index` / `Locking N packages to latest compatible versions` / `Adding …`. A synced lock shows none of these next clean build. **Apps only** — libraries carry no committed lock (the app's lock governs them). These syncs become the **separate** Cargo.lock MRs in Step 7 (`create_cargolock_mrs.sh`), kept out of the clippy MR.

## Step 7 — MR rollout

Use `scripts/` (all DRY-RUN by default, `--go` to act, `SLEEP=3` to avoid GitLab issue-creation rate-limit, `TOKEN_FILE=` for a PAT with `api` scope):
- `create_clippy_lib_mrs.sh` — lib: open issue → branch `<iid>-clippy-scan-binary-packages` from `clippy-scan-binary-packages-3`, amend its single commit to `Issue #<iid>: …`, push, MR.
- `create_clippy_app_mrs.sh` — app: branch from **fetched** `origin/<target>`, `git checkout <srcbranch> -- '(^|/)Makefile$'` (Makefile-only → excludes Cargo.lock, squashes stale `-p`/dup commits), single commit, MR.
- `create_cargolock_mrs.sh` — separate Cargo.lock-sync MR (cherry-pick the "Synchonize Cargo.lock" commit onto fetched base).
- `check_rust_app_lock.sh` — flags dl↔output/build Cargo.lock drift (exit 1 on drift; CI gate).

Merge via API: `PUT /projects/:enc/merge_requests/:iid/merge` (retry while `detailed_merge_status=checking`).

## Gotchas (all hit for real)

| Gotcha | Detail |
|---|---|
| `cargo clippy -p <lib>` | Does NOT lint path deps (only `Checking`). Must use `RUSTC_WRAPPER=clippy-driver`. |
| project path regex | Some repos' `git remote get-url origin` has **no `.git` suffix` → a regex requiring `\.git$` yields a malformed path → GitLab API 404 "Project Not Found" (looks like permissions). Use `sed -E 's#^.*gitlab\.com[:/]##; s#\.git$##; s#/#%2F#g'`. |
| issue-creation rate-limit | Rapid POSTs intermittently fail even with access. `SLEEP=3`; idempotent re-run skips done repos. |
| issues don't auto-close | `Closes #N` only auto-closes when merging to the **default branch** (often `develop`), not `NOS_v6.0_develop`. |
| token format | `~/moxa_gitlab_scm_token` may be `<label>glpat-<PAT>`; extract with `grep -oE 'glpat-[A-Za-z0-9._-]+'`. |
| Cargo.toml stays | Never remove a lib's Cargo.toml — it defines the crate. Only the SCAN machinery + MSRV add-ons (`rust-version`, standalone `.cargo/config.toml`) become removable. |
| `RUST_TARGET_DIR` | Removed from lib `.mk` (dead after scan removal), kept in app `.mk`. |
| stale Cargo.lock | A bad gitignored Cargo.lock left in `dl/<pkg>/` is invisible to `git status` but rsynced into the build tree → cargo honors it, MSRV fix never runs. Tell-tale: error with NO `Updating crates.io index / Locking N packages` preceding it. |
| meld | User's git has external diff → always `git ... --no-ext-diff`; report verdicts, don't dump diffs. |

## Durable alternative to per-package Cargo.toml pinning

Per-package MSRV pinning (#4190 style) is whack-a-mole. Root cure = freeze the dep set: committed `Cargo.lock` per app (+ by-application scan so libs never resolve standalone) + CI `--locked`; strongest = `cargo vendor`. `resolver="3"`/`incompatible-rust-versions="fallback"` only reduces, never guarantees.
