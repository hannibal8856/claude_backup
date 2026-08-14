---
name: feedback-build-order
description: Buildroot rebuild order — plugin_moxa_snmp must be rebuilt before rust_moxa_build (then final make)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f799ca36-ae55-4954-a42d-21c79180a90b
  modified: 2026-08-12T07:39:07.728Z
---

## ⭐ 2026-08-12:已固化成腳本,不要再手打指令串

**`~/mds4xgl3/rebuild_snmp_plan_e.sh`**(與 `hsm_sign_fwr.sh` 同層,可執行)

```
./rebuild_snmp_plan_e.sh              # 完整鏈
./rebuild_snmp_plan_e.sh --rust-only  # 僅在改動侷限於兩個 workspace member 自己的 src/ 時安全
./rebuild_snmp_plan_e.sh --dry-run    # 只印指令
```

順序寫成三個有序陣列(`STAGE_LIBS` / `STAGE_RUST_MEMBERS` / `STAGE_PLUGINS`),
build 前會無條件 `cp -n` 備份 `.swu` 到 `~/swu/`(見 [[project-swu-lives-in-two-places]])。

## ⚠️ 排序規則的正確版本(比「workspace member」寬很多)

**排序需求的來源不是「是不是 workspace member」,而是「cargo 會不會透過
`path = "../../<pkg>-custom"` 讀它」。** 2026-08-12 實測:

```
grep -c 'path = "\.\./\.\./' dl/app_moxa_framework/Cargo.toml   →  25
```

**25 條 path 依賴,全部指向 sibling 的 `-custom` 目錄**(由 `<pkg>-rebuild` 的 rsync 填),
其中 23 個不在腳本的陣列裡:`plugins_moxa_framework`(**複數,別跟 `plugin_moxa_*` 搞混**)、
`rust_moxa_common` / `bff` / `auth_layer` / `status_layer` / `config_layer` / `command_layer` /
`file_layer` / `app_state` / `profiling`、`app_moxa_token_module`、
`lib_moxa_rust_debug_log_ng` / `encrypt` / `event_action` / `firmware_header` / `io` /
`led_service` / `pam` 等。

**改到這 23 個裡的任何一個,失敗模式完全相同**(cargo 編到舊 source、exit 0、
症狀是「改了沒生效」)→ 要把它加進 `STAGE_LIBS` 再跑。

底層成因(結構證據,非慣例):
```
output/build/rust_moxa_build-custom/app_moxa_framework -> ../app_moxa_framework-custom   (symlink)
dl/rust_moxa_build/Cargo.toml  [workspace] members = ["app_moxa_framework","app_moxa_iss_config_loader"]
```

---

原始記錄(2026-08-09,順序仍正確,細節見上):

```
make 3rdparty_net_snmp-rebuild
make plugin_moxa_snmp-rebuild        # MUST be before rust_moxa_build-rebuild
make rust_moxa_build-rebuild
make                                  # final image
```

**Why:** User corrected my initial ordering (which had rust_moxa_build before plugin_moxa_snmp). Likely because rust_moxa_build consumes generated/installed artifacts from plugin_moxa_snmp (or the rust glue depends on snmp plugin headers/.so being in staging first). Reversing the order risks a stale-link or rust-build-against-old-snmp-plugin situation, even if neither errors visibly.

**How to apply:** Any time the user asks for a chained rebuild that touches both `plugin_moxa_snmp` and `rust_moxa_build`, put `plugin_moxa_snmp-rebuild` first. The full chain above is the canonical sequence after editing C in 3rdparty_net_snmp + plugin_moxa_snmp.

**Rust binaries (`app_moxa_framework`, `app_moxa_iss_config_loader`, …) are compiled ONLY by `rust_moxa_build` (2026-07-14):** their own package (`app_moxa_framework-custom`) has an EMPTY Makefile and NO `_BUILD_CMDS` in the `.mk` — `make app_moxa_framework-rebuild` only rsyncs source + installs, it does NOT run cargo, so the installed binary stays stale. The actual `cargo build --workspace` lives in `rust_moxa_build` (`dl/rust_moxa_build/Cargo.toml` `[workspace] members=["app_moxa_framework", …]`; it symlinks/uses the sibling `output/build/<pkg>-custom` dirs). So after editing any Rust binary/crate source: `make <pkg>-rebuild` (to rsync the new source into `output/build/<pkg>-custom`) THEN `make rust_moxa_build-rebuild` (to recompile), THEN `make` (image). Skipping `rust_moxa_build` = old binary in the image → symptom looked like "code change had no effect" (e.g. new AgentX subagent OID returned No Such Object because the framework binary was never recompiled).

⚠️ **2026-08-09:踩到的是另一半 —— 漏掉 `make app_moxa_framework-rebuild`(只跑了 `rust_moxa_build-rebuild`)。**
`rust_moxa_build` 只 build workspace,**不會 rsync 各 crate 的原始碼**,所以
`output/build/app_moxa_framework-custom/src/` 停在幾天前,cargo 編的是舊碼、還 exit 0。
症狀:C 端 mapping 完全正確,但 SNMP 回 noSuchInstance,像是 Rust handler 沒認得新的 table_col。
浪費了一次完整 build + 燒錄。

**30 秒自檢(改完 Rust、build 前一定要做):**
```bash
grep -c '<你剛加的識別字>' output/build/<pkg>-custom/src/<file>.rs
ls -ld output/build/<pkg>-custom          # 日期應該是「剛剛」
```
0 命中或日期是舊的 → 先 `make <pkg>-rebuild`。

**查「C 對但 Rust 不對」的利器**:`libmoxaiesautomibs` 有匯出 `ies_map_count()` /
`ies_map_entry_at()`,用容器裡的 toolchain 交叉編一支小程式丟到 DUT 上跑,
就能直接印出執行期的 `table_col` / `uri_index` / `is_status`,一眼分辨是 C 還是 Rust 的問題。
範例留在 `~/sofswap/dumpmap.c`。
