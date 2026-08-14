---
name: project-pysnmp-shadows-snmpwalk
description: "使用者工作機的 snmp* 命令被 ~/.local/bin 的 pysnmp 版蓋掉,一律加 /usr/bin 前綴"
metadata: 
  node_type: memory
  type: user
  originSessionId: 29daee49-bef3-468c-b065-99511fefffc3
  modified: 2026-08-09T08:45:48.850Z
---

**使用者 2026-08-09 明示:「我的工作機 snmp 系列命令要加上 `/usr/bin`,不然會被導到奇怪版本。」
所有 `snmp*` 命令一律寫絕對路徑 `/usr/bin/snmpXXX`,不要有例外。**

已確認被蓋掉的:`snmpwalk`、`snmpget`、**`snmptranslate`**。
已確認沒被蓋的:`snmpgetnext`。**但不要靠這份清單** —— 一律加前綴最省事。

使用者工作機上 `~/.local/bin/` 有 **pysnmp 版**的 snmp 命令,
在 PATH 中排在 `/usr/bin/`(net-snmp 5.8)前面:

```
$ which -a snmpwalk
/home/moxa/.local/bin/snmpwalk     <- pysnmp,會壞
/usr/bin/snmpwalk                  <- net-snmp 5.8,要用這個
```

**pysnmp 版的症狀**:對 DUT 走 walk 會噴 `CryptographyDeprecationWarning` 和
`AbstractTransportDispatcher._cbFun` 的 traceback,然後**掛住直到 timeout、回 0 個 varbind**。
看起來一模一樣就像「DUT 的 snmpd 卡死了」。

⚠️ **`snmpgetnext` 沒有被蓋**(只有 walk 和 get)。所以會出現
「getnext 秒回、walk 完全不動」的組合 —— 這個組合極具誤導性,很容易誤判成
GETNEXT loop 或 subagent 沒註冊上去。

**How to apply:** 所有量測腳本一律寫**絕對路徑** `/usr/bin/snmpwalk`。
`~/mds4xgl3/tools/walkmeasure.sh` 和 `~/sofswap/measure.sh` 已經是絕對路徑,所以它們的數字可信;
手打的 ad-hoc 指令才是危險的。

**Why:** 2026-08-09 用它驗證 A/B 對照組時,ad-hoc 的 `snmpwalk` 讓我連續誤判兩次
——先以為 mxTurboRingV2 有 GETNEXT loop,再以為 snmpd 被我弄掛,還因此多重開了一次 DUT。
`/usr/bin/snmpwalk` 一測就發現 DUT 一直是好的。

相關:[[project-snmp-walk-slow-diagnosis]] —— 那則講「先分辨讀值慢 or GETNEXT 慢」,
這則是更前面一步:**先確認你跑的是哪一支 snmpwalk**。
