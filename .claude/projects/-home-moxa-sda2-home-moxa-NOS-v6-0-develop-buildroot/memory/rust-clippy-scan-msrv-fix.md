---
name: rust-clippy-scan-msrv-fix
description: How to fix RUST_CLIPPY_SCAN_CONFIG=true build failures caused by pinned rustc 1.85 vs newer crates
metadata: 
  node_type: memory
  type: project
  originSessionId: 83e4c1bb-bfab-49ce-95ca-be756d827814
---

Building moxa rust crates with `RUST_CLIPPY_SCAN_CONFIG=true` fails because the toolchain pins **rustc 1.85.0** but crates (no committed Cargo.lock; `/Cargo.lock` is gitignored) resolve to newest versions needing rustc ≥1.86–1.88.

**Why:** default cargo resolver ignores deps' MSRV; also some deps lie (no `rust-version` metadata but actually need newer rustc).

**How to apply — two distinct problem types:**

1. Resolver error `requires rustc 1.88` (actix-http, time, icu_*, bytestring, idna...). Fix per crate:
   - add `rust-version = "1.85.0"` to `[package]` in its `Cargo.toml`
   - add to `.cargo/config.toml` (create if missing): `[resolver]\nincompatible-rust-versions = "fallback"`
   This makes cargo pick 1.85-compatible versions even without a Cargo.lock. Verified working.

2. Compile error `error[E0658]: let expressions ... unstable` from a dep that declares NO `rust-version`, so the resolver can't avoid it (e.g. `subprocess`: let-chains added in 0.2.10, needs rustc 1.88). Fix: exact-pin to last good version, e.g. `subprocess = "=0.2.9"`. The `rust-version`+resolver trick does NOT catch these.

3. **Stale gitignored Cargo.lock in dl/ overrides everything** (hit 2026-06-10, plugin_moxa_firmware_update/framework). A bad lock (latest versions) left in `dl/<pkg>/<dir>/` is invisible to `git status` (`.gitignore` has `/Cargo.lock`) but buildroot's rsync copies it into the build tree; cargo then honors the lock, skips resolution entirely, and the MSRV fix (#1) never gets a chance. **Tell-tale in the log: `error: rustc 1.85.0 is not supported` with NO preceding `Updating crates.io index / Locking N packages` lines** — resolution didn't run, so a lock exists. Also note: for some dep trees (firmware_update framework: actix-web+reqwest+jsonschema) `incompatible-rust-versions = "fallback"` alone CANNOT reach a fully-1.85 set (best it finds is icu 2.1.x / bytestring 1.5.0); the durable fix is a Cargo.lock pinned to known-good versions (bytestring 1.4.0, icu_* 2.0.x, idna_adapter 1.2.1 — same as app/'s committed lock). Generate it in the container build tree (path deps `../../*-custom` only resolve there), then `cp` back to dl/. Done for firmware_update/framework on 2026-06-10; lock is still gitignored there — needs `git add -f` or .gitignore edit to persist in git.

**Notes:**
- Some crates keep their Rust source in a `framework/` subdir (e.g. `plugin_moxa_profinet`); clippy runs `cd framework && cargo clippy`, so both edits go under `framework/`. Find the real dir via the `cargo clippy` line in the crate's Makefile.
- Each crate under `dl/` is its OWN git repo. Convention used: branch `cargo-clippy-without-cargo-lock`, commit msg `fix clippy scan`. `.cargo/config.toml` is a new file so `git commit -a` misses it — `git add` it explicitly.
- 177 clippy crates total (across ~167 package repos + the rust_moxa_build workspace). As of 2026-06-05 the MSRV patch was batch-applied + committed (branch `cargo-clippy-without-cargo-lock`, msg "fix clippy scan") to ALL of them. Not yet pushed.
- Type-2 subprocess direct-deps pinned to `=0.2.9`: lib_moxa_rust_system_information, plugin_moxa_ip_interface, plugin_moxa_web_crt (others get 0.2.9 transitively).
- `rust_moxa_build` is a `[workspace]` (members app_moxa_framework, app_moxa_iss_config_loader) scanned via `cargo clippy -p <member>`. Fix = `[resolver] fallback` in rust_moxa_build/.cargo/config.toml + `rust-version=1.85.0` on both member packages' Cargo.toml.
- Batch gotcha: `git status --porcelain` lists a new untracked dir as `.cargo/` (not the file), so filtering by `config.toml$` misses it; use `git add -A` per repo.
- **A crate with a committed (git-tracked) Cargo.lock does NOT need MSRV** — cargo uses the lock and skips re-resolution (the step that throws `rustc 1.85.0 is not supported`). Verified all such committed locks pin 1.85-compatible versions (actix-web 4.11.0, time 0.3.41, subprocess 0.2.9, icu 2.0.1, bytestring 1.4.0). On 2026-06-05 these were reverted to origin/NOS_v6.0_develop (MSRV patch removed): full-revert = 6× app_moxa_* (email_notification, new_moxa_command_broadcast_search, system_monitor, token_and_user_status_daemon, token_module, trap_notification), plugin_moxa_md_type_detect, rust_moxa_build + members app_moxa_framework & app_moxa_iss_config_loader (covered by rust_moxa_build's workspace lock). Partial-revert (lock only in one sub-crate; kept MSRV on lockless `framework/`): plugin_moxa_{arp_table,cli_export,firmware_update,hardware_interface,locator,relay} (lock in app/), plugin_moxa_mms (modify_stackcfg/), plugin_moxa_user_account (control/). plugin_moxa_aide kept MSRV (lock is in non-clippy app/; clippy scans only framework/).

See [[build-and-verify-via-docker]] for running the actual rustc-1.85 verification.
