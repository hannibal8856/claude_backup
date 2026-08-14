---
name: project-ies-auto-mibs-setup-no-dep-tracking
description: "只改 ies_auto_mibs_setup.c 不會觸發重編,增量 build 會靜默出貨舊碼"
metadata: 
  node_type: memory
  type: project
  originSessionId: 29daee49-bef3-468c-b065-99511fefffc3
  modified: 2026-08-09T02:04:20.264Z
---

`3rdparty_net_snmp` 的 build 目錄下**沒有任何 `.deps` / `.Plo` / `.d`**
(configure 帶 `--disable-dependency-tracking`)。而
`ies-auto-mibs/ies_auto_mibs_setup.c` 不是獨立編譯單元 —— 它被
`ies_auto_mibs.c:2591` `#include` 進去,一起編成
`ies-auto-mibs/.libs/ies_auto_mibs.o` → `libnetsnmpmibs.so.40.2.0`。

**後果:只改 `ies_auto_mibs_setup.c` 然後跑 `make 3rdparty_net_snmp-rebuild`,
`ies_auto_mibs.o` 不會重編,產出的 .so 與改動前 byte-identical,build 完全不報錯。**

Plan E 那 13 個註解掉的 `MOX_SNMP_INIT_ENTRY`(in-master 退出機制)就住在這個檔,
所以這條路徑正是最容易踩到的。

**How to apply:** 動到 `ies_auto_mibs_setup.c`(或任何被 `#include` 的 .c)之後,
一定要強制重編再 build:

```bash
touch dl/3rdparty_net_snmp/ies-auto-mibs/ies_auto_mibs.c
rm -f output/build/3rdparty_net_snmp-custom/ies-auto-mibs/.libs/ies_auto_mibs.o \
      output/build/3rdparty_net_snmp-custom/ies-auto-mibs/ies_auto_mibs.lo
```

**Why:** 2026-08-09 做 in-master 註冊表根因對照組時,變體 B(13 個註解還原)
編出來的 .so 與變體 A 的 md5 一模一樣才發現。若沒比 md5,整個實驗會得到
「還原註冊沒有變慢」的假陰性,並直接把 outline CIC 的歸因寫反。

**驗證方式:** 每次都比 `md5sum`,或確認
`output/build/.../ies-auto-mibs/.libs/ies_auto_mibs.o` 的 mtime **晚於**
`ies_auto_mibs_setup.c`。

相關:[[project-build-seq-needs-3rdparty-net-snmp]]、
[[project-agentx-owned-list-parser-landmine]] —— 三則都是「build 不報錯但東西是錯的」同一類。
