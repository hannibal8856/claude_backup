---
name: project_vincent_proposal_evaluation
description: "Vincent 的 3rdparty_net_snmp 提案:#3 分級 TTL 照做是靜默無效,#1 的 arch 旗標跨三個 CPU 家族會壞;ADR-0026"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac72d867-b88f-4f5f-9331-a1243ef368f8
  modified: 2026-08-11T10:13:13.696Z
---

Vincent Tung《3rdparty_net_snmp enhancement》(Confluence,2026-03-23,Draft,PDF 存於
`~/WORK/SNMP_50ms/`)提 6 個瓶頸 + 3 個架構選項。**全文數字皆為 estimated,文件自己也載明未經量測。**
評估結論見 **ADR-0026**。

**#3 分級 TTL —— 否決,照做等於什麼都沒做。** 三項前提皆錯:
① 要改的 `moxa_snmp_const.h:23-24` 常數**沒有任何 .c 引用**,生效的是
`entry_handle_check_value_file()` 內重新 `#define` 的局部同名常數(`ies_auto_mibs.c:2027-2028`);
② 800ms 分支**不可達**(`:2099-2108` 的 if/else 兩邊都 return),實際 TTL 只有 200ms 的 LAST_ACCESS;
③ `gSnmpTblSnapShot` 是**單槽快照**不是多筆快取,且 scalar 從不快取。

**#1 編譯旗標 —— 方向對,但文件那行 patch 不能照抄。**
`-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard` 跨三個 CPU 家族各壞一種:
CN9130(ARMv8/aarch64)編不過;PJ4B-MP(現行 DUT,cpuinfo 無 `neon`)會產生不支援的指令;
AM335X(Cortex-A8 單核)世代也不對。arch 旗標交由 buildroot `toolchain-wrapper` 處理,**一個都不要手寫**。
只加 `-O3 -flto`,且要設在 buildroot 層(`BR2_TARGET_OPTIMIZATION`,目前是空的)。
文件還漏了兩個真正的熱區:net-snmp/`ies-auto-mibs` 本體(`--with-cflags` 覆蓋掉 autoconf 的 `-g -O2`)
與 `rust_moxa_build`(→ `app_moxa_framework`,也是 `opt-level="s"`)。

**Why:** 兩項都被文件標為「1.5 天、零風險 Quick Win」,實際上一個無效、一個會弄壞跨平台 build。
而且兩者都建立在「讀取路徑是瓶頸」的假設上 —— 那個假設**已經被 ADR-0008 的實測推翻過一次並 revert**
(真因是 GETNEXT 跨未註冊區間的 probe,ADR-0009)。

**How to apply:** 引用這份文件前先正名三件事:它假設 net-snmp **5.8** 且 ies-auto-mibs 在
`net-snmp-5.8/agent/mibgroup/`(實際是 5.9.3 且已移出),第 12 節路徑無一正確;
它把 `127.0.0.1:80` 後端叫 "ISS (Internal Settings Server)" 且說是 "Flask-based"
(實際是 nginx → Rust actix,且與我方語彙的 ISS 是**完全不同的元件**)。
真正值得接手的是 #4 fork/exec —— 見 [[project_frameworkuri_reconnects_per_request]] 與
`~/WORK/SNMP_50ms/in-master-read-path-findings-2026-08-11.md` 的 8 處盤點。
