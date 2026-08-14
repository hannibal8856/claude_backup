---
name: clippy-nos7-branch-state
description: "NOS7 by-application clippy rollout in ~/clippy-scan-binary-packages-3-nos7 — steps 1-5 verified, 11 lib .mk backfilled, 8 RKS-PL packages deferred"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1240745b-0001-4e08-a589-bed6e137a069
  modified: 2026-08-05T09:02:57.555Z
---

2026-08-05, workspace `~/clippy-scan-binary-packages-3-nos7` (buildroot on `develop`,
`buildroot/moxa` on branch `clippy-scan-binary-packages-3-nos7-2`).

**Steps 1-5 of [[clippy-by-application-scan]] verified done on NOS7.** 21 BIN crates in
18 dl Makefiles, all `RUSTC_WRAPPER=clippy-driver cargo check`; zero `cargo clippy` left;
161 libs clean. `output/images/cargo` holds exactly 21 json. No canary needed — the json
already carry 66 real clippy diagnostics attributed to **library** crates
(plugin_*/framework, plugins_moxa_framework, lib_moxa_rust_new_moxa_command), which proves
clippy ran on the path-dep closure. 168/171 real rust pkgs covered; only
`rust_moxa_profiling` prints the informational `Note:` (by design, not a failure).

**The nos7 branch did NOT inherit the v6.0 cleanup.** v6.0's `100c384df` (Issue #4451)
touched 163 `.mk`; nos7 has its own `ff5634025` touching only 152. Neither `100c384df`
nor `7fb947c3c` is an ancestor of the nos7 branch. Backfilled the missing 11 as commit
`a1a7e5e5d` (11 files, +4 -50, byte-identical diffstat to v6.0's). `RUST_TARGET_DIR` was
removed in only 5 of the 11 — v6.0 made that call per-package (keep it where the dl
Makefile's normal build also uses it, not just the scan); copy that decision, don't re-derive.

**Why:** left alone, a product config that enables those 11 would trip post-build.sh's hard
gate ("did not produce a Rust Clippy scan result"). Harmless in this defconfig because the
gate guards with `[ -d ${BUILD_DIR}/${pkg}-custom ]`.

**How to apply:** 8 `.mk` still export `rust_clippy_scan_result` without producing json —
`app_moxa_oob_management`, `plugin_moxa_oob_management`, `lib_moxa_rust_intel_temp_ctrl`,
`plugin_moxa_intel_temp_ctrl`, `plugin_moxa_export_cli_submode_interface_mgmt`,
`plugin_moxa_frontenddata`, `plugin_moxa_panel_desc_data`, `plugin_moxa_web_csr`.
All came from `08a9373ca` "Issue #3460: [RKS-PL] Support Rust clippy scan", which is NOT
a v6.0 ancestor — so v6.0 never had them, they were not "missed". They are enabled by no
nos7 defconfig and absent from `dl/`, so app-vs-lib cannot be judged here; clone from the
`.mk`'s `_SITE` or use an RKS-PL defconfig. User said 2026-08-05: leave them for now.
These 8 are byte-identical to `origin/develop` on this branch.

**Before opening the MR:** the branch also carries 8 `configs/*_defconfig` with ~1273 lines
pinning every `_REV` to `"clippy-scan-binary-packages-3-nos7"` — local test scaffolding from
the `Add`/`Update` commits, must NOT be merged. MR should contain only the 162
`package/net/*.mk` + `board/net/common/post-build.sh`.

Related: [[clippy-by-application-scan]], [[clippy-gitlab-mr-workflow]], [[git-no-ext-diff]].
