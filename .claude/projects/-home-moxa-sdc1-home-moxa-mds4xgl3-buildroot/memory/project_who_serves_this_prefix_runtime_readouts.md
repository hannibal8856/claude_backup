---
name: project_who_serves_this_prefix_runtime_readouts
description: "「這個前綴是誰在服務」「這欄是 RO 還是 RW」只能從執行期讀 — net_*.h 的 .mode 會被 setup_entry_flags 覆寫,T4 GATE 才是服務者的直接讀數"
metadata: 
  node_type: memory
  type: project
  originSessionId: 866e21a4-9a43-4cf9-8e46-6d4b75d0b7f7
  modified: 2026-08-12T19:31:47.625Z
---

判斷 `+getfwd` 適不適用某個前綴,**兩個關鍵事實都不能從原始碼靜態推**:

**① `net_*.h` 的 `.mode` 不是實際 mode。**
`ies_auto_mibs_setup_net_*.c` 會在註冊前覆寫它。實例:
`ies_auto_mibs_setup_net_mxQosdb.c:134` 把 map 宣告為 `HANDLER_CAN_RWRITE` 的
`qosConfigMeterColorModeType` 改成 `HANDLER_CAN_RONLY`。
→ **任何只讀 `net_*.h` 做的 RO/RW 普查都不可靠**(那份「11 個全 RW 前綴」清單就是這樣來的,
`mxqosdb/` 實際有 1 個 RO)。要嘛看執行期 `T1 NOTE`,要嘛連 setup 檔一起解析。

**② `T4 GATE` 有沒有出現 = 這個前綴到底是誰在服務。**
沒有 `T4 GATE` → 請求根本沒進 in-master,ISS 已直接接走,**`+getfwd` 對它沒有意義**
(`stdlldp/` 就是這種:封包顯示 GET 有送到 ISS,但 trace 一筆 `T4 GATE` 都沒有)。
有 → in-master 在服務,才輪得到轉發。

**Why:** 2026-08-12 我先挑 `stdlldp/` 當測試標的,白跑一輪;又因為信了靜態清單的
「0 RO」,對 `mxqosdb/` 出現的 probe 候選困惑了很久。

**How to apply:** 要評估一個前綴之前,先開 trace、對它的一個 RW 欄下 GET,看有沒有
`T4 GATE`。有才繼續。RO/RW 的實際分佈看重啟後的 `T1 NOTE` 逐前綴計數。

⚠️ **snmpd 重啟會清掉 trace 旗標** —— 見 [[project_snmpd_restart_clears_trace_flag]],
不重新 enable 的話上面兩個讀數都會是空的,而「空的」看起來跟「沒發生」一模一樣。

相關:[[project_getfwd_noop_on_mxportdb_stdethdb]]、[[project_iss_coverage_screen_before_delegating]]、
ADR-0030、ADR-0031。
