---
name: project_build_seq_needs_3rdparty_net_snmp
description: "改 ies_auto_mibs.c 一定要先 make 3rdparty_net_snmp-rebuild,否則不會被編進 image;git diff 被 alias 到 meld,要用 --no-ext-diff"
metadata: 
  node_type: memory
  type: project
  originSessionId: 03565926-6fb8-4a69-a12c-4471723877ba
  modified: 2026-08-12T07:34:58.585Z
---

**`ies_auto_mibs.c` 是 `3rdparty_net_snmp` 這個 package 在編**,不是
`lib_moxa_ies_auto_mibs`。session doc(2026-08-06)Appendix D 的建置序列從
`lib_moxa_ies_auto_mibs-rebuild` 開始,**漏了這一步** —— 照那個序列建,C 層改動
完全不會進 image(2026-08-07 實際踩到,build 完 exit 0 但 `.so` 裡沒有新符號)。

一直沒被發現的原因:ADR-0011/0012 那輪只改 `agentx_owned.list`(純資料,由
`plugin_moxa_snmp` 安裝),不需要 C 重編。

對齊全樹的完整序列(2026-08-07 驗證可用,最後的 `make` 會直接產出 .swu,
**沒有停在 HSM 簽章**):

```bash
run_in_docker.sh "make lib_moxa_utility-rebuild && make 3rdparty_net_snmp-rebuild \
 && make app_moxa_iss_10_1_0-rebuild && make lib_moxa_ies_auto_mibs-rebuild \
 && make lib_moxa_rust_ies_auto_mibs-rebuild && make lib_moxa_rust_snmp_agentx-rebuild \
 && make app_moxa_fiber_check-rebuild && make plugin_moxa_snmp-rebuild \
 && make plugin_moxa_fiber_check-rebuild && make plugin_moxa_system_information-rebuild \
 && make app_moxa_framework-rebuild && make rust_moxa_build-rebuild && make" mds4xgl3
```

✅ **2026-08-12 起改用 script,不要再手打這串:`~/mds4xgl3/rebuild_snmp_plan_e.sh`**
(`--dry-run` 印指令、`--rust-only` 只跑 Rust 那段)。順序寫死在裡面,理由寫在檔頭。
使用者要求把這件事固化成 script,因為同一個順序錯誤已經發生兩次。

🔴 **2026-08-12 更正:`app_moxa_framework-rebuild` 必須在 `rust_moxa_build-rebuild`
之前。** 本檔原本記的是相反的順序(`rust_moxa_build` 在前),與
[[feedback-build-order]] 的 2026-08-09 增補直接矛盾,而我照了這一條、被使用者當場糾正。
**使用者原話:「app_moxa_framework 要先 build 完再 build rust_moxa_build」「plugin_moxa 系列也一樣」。**

**⚠️ 我第一次寫這條更正時把範圍寫得太寬(「所有 `app_moxa_*`」),使用者再次糾正:
「不是所有的 `app_moxa_*`;只有 `app_moxa_framework` 和 `app_moxa_iss_config_loader`
需要 `rust_moxa_build-rebuild`」。** 以 `dl/rust_moxa_build/Cargo.toml` 實查為準:

```toml
[workspace]
members = [ "app_moxa_framework", "app_moxa_iss_config_loader" ]
```

**workspace 成員就這兩個,沒有其他 `app_moxa_*`,也沒有任何 `plugin_moxa_*`。**

精確的規則是兩條、理由不同:

1. **`app_moxa_framework` / `app_moxa_iss_config_loader`(Rust workspace 成員)**
   的 `-rebuild` 必須在 `rust_moxa_build-rebuild` **之前** —— `<pkg>-rebuild` 負責把
   crate 原始碼 rsync 進 `output/build/<pkg>-custom/`,`rust_moxa_build` 才是真正跑
   `cargo build --workspace` 的那步。順序顛倒 cargo 編到舊 source,**而且 exit 0**。
   其餘 `app_moxa_*`(`app_moxa_iss_10_1_0`、`app_moxa_fiber_check` …)**不是 Rust,
   沒有這個順序需求**。
2. **`plugin_moxa_*` 也要排在 `rust_moxa_build-rebuild` 之前**(使用者 2026-08-12
   重申「plugin_moxa 系列也一樣」),但理由不是 workspace 成員 —— 見
   [[feedback-build-order]],推測是 rust 端會用到 plugin 裝進 staging 的產物。

`run_in_docker.sh` 在 `/usr/local/bin/`。所有 `plugin_moxa_*` 都要排在
`rust_moxa_build-rebuild` 之前([[feedback-build-order]])。

**驗證改動真的進了 binary**:掃 `output/target/usr/lib/libnetsnmpmibs.so.40.2.0`
的 OID 位元組(little-endian uint32)。注意選有鑑別力的樣本 —— 欄位 OID 本身在
`net_*db.h` 裡也有,會偽陽性;要用只存在於新程式碼的常數(例如帶 instance 的 probe OID)。

**兩個會咬人的環境問題:**
- `git diff` 被使用者 alias 導到 meld → 產出的 patch 是空的。要用
  `git diff --no-ext-diff`,或直接 `diff -u <dl 的檔> <output/build 的副本>`。
- `make` 會**刪掉 `output/images/` 裡舊的 .swu**(只留 `.config`)。要保留對照組
  image,build 前先 `cp` 到 `~/swu/`。

**hotswap 是有效的驗證手段**:2026-08-07 用 hotswap 得到的失敗結果,完整燒錄後
逐項複製(walk 13 筆、逐表 16/1/19/60/30、8 個 RW 值全同、pcap 大小都一樣)。
但當時**沒跑「同一輪重建、不含改動」的對照組**,所以在完整燒錄前不該把結論說死。
相關:[[project_build_tree_and_container]]、[[project_getfwd_probe_must_be_wire_verified]]
