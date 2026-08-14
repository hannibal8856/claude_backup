---
name: project_cross_package_header_no_rebuild
description: "跨 package 的 header 改動不會觸發 lib_moxa_ies_auto_mibs 重編,而且「有沒有編到」的檢查會過 — 過的是錯的那個 .so"
metadata: 
  node_type: memory
  type: project
  originSessionId: ee275acd-d869-43fd-ba9b-5fe897b8db7b
  modified: 2026-08-12T03:39:09.338Z
---

2026-08-12 實測(搬 `fiber_check_event` 時踩到,差一步就出貨壞 image)。

## 症狀

改了 `3rdparty_net_snmp/ies-auto-mibs/net_mx_event_port.h`,跑完
`make 3rdparty_net_snmp-rebuild && make lib_moxa_ies_auto_mibs-rebuild && make`:

| 檢查 | 結果 |
|---|---|
| `make` | **exit 0,零錯誤** |
| `libnetsnmpmibs.so.40.2.0` md5 | **變了** ✓ |
| `libnetsnmpmibs.so` 含新字串 | **8 筆** ✓ |
| **`libmoxaiesautomibs.so.1.0.0` md5** | **完全沒變** ✗ |
| **`libmoxaiesautomibs.so` 含新字串** | **0 筆** ✗ |

## 根因

`lib_moxa_ies_auto_mibs` 用
`-I$(TOPDIR)/dl/3rdparty_net_snmp/ies-auto-mibs`(**指向原始碼樹,不是 staging 複本**)
拉外部 header,但它自己 `Makefile` 的
`HEADER_FILES=$(shell find ${INCLUDE_PATH} ${SRC_PATH} -name "*.h")`
**只掃自己的目錄** → 外部 header 改了,它永遠不認為 `mapping_reuse.o` 過期。

## 為什麼特別惡劣

**變的是 in-master 那側(`libnetsnmpmibs.so`),而那份 array 往往是死碼** ——
已搬遷的 group 其 `MOX_SNMP_INIT_ENTRY` 是註解掉的,編進去也不註冊。
**真正生效的 framework 那側(`libmoxaiesautomibs.so`)沒動。**

所以「有沒有編到」這個檢查**會過,但過的是錯的那一個**。若照著燒下去:
dlmod 已停用 + framework 沒有那些 entry → 該 OID 全部回 `No Such Object`,
而最自然的解讀是「map 寫錯」或「dlmod 退出機制有問題」—— 會往完全錯的方向查。

`snmp outline CIC 3` 同日從反面繞過同一個坑:他刻意只跑
`plugin_moxa_snmp-rebuild && make`,若照完整序列跑就會踩到鏡像版
(以為 3rdparty 重建了就等於改動生效)。

**共同形狀:這棵樹上「編了什麼」與「誰在服務」是兩件事,驗證要對準後者。**

## 修法

```
rm -f output/build/lib_moxa_ies_auto_mibs-custom/src/*.o \
      output/build/lib_moxa_ies_auto_mibs-custom/*.so*
touch dl/lib_moxa_ies_auto_mibs/src/mapping_reuse.c
make lib_moxa_ies_auto_mibs-rebuild && make
```

實測 md5 `520bff0d…` → `616a0b07…`、字串 0 → 8 筆。

**How to apply:** 動到任何 `net_*.h` 或跨 package 的 header 之後,
**兩個 `.so` 都要比 md5,而且要 grep 新字串**,不能只比一個 ——
先問「哪個 `.so` 才是真正服務這個 OID 的」,再驗那一個。
判別方法:`MOX_SNMP_INIT_ENTRY` 註解掉的 group → framework
(`libmoxaiesautomibs.so`);未註解 → in-master(`libnetsnmpmibs.so`);
兩邊都有 → in-master 以 priority 127 勝出。
最後再確認 `rootfs.squashfs` 的 mtime **晚於**修好的 `.so`。
相關:[[project_ies_auto_mibs_setup_no_dep_tracking]]、[[feedback_build_order]]
