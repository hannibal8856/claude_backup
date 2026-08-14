---
name: feedback_pcap_retention_discipline
description: pcap 是證據不是暫存檔 — 交還 DUT 前先 scp 回 ~/pcap/ 再清 /tmp;檔名格式與 .tcpdump.log sidecar 的意義
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 866e21a4-9a43-4cf9-8e46-6d4b75d0b7f7
  modified: 2026-08-12T06:40:26.267Z
---

**清 `/tmp` 之前,先把擷取檔取回 `~/pcap/`。** 2026-08-12 照「交還前清乾淨」這條規則
清掉了**六次 pcap 判定的擷取檔**,只剩報告裡的封包數。規範已修訂進 **ADR-0027 ④**。

**Why:** 封包數是**主張**,pcap 才是**證據**。檔案沒了,可重驗的結論就降級成一句斷言 ——
而這條線上「寫錯的紀錄比沒有紀錄更貴」已被證明三次(ADR-0018、ADR-0025、ADR-0028)。
而且 `fwdcheck.sh` / `walkpcap.sh` 固定寫死 `/tmp/fwdcheck.pcap` / `/tmp/walkpcap.pcap`,
**下一次執行會直接覆蓋**,連「等一下再取」都不成立。

**How to apply:**

1. 交還 DUT 固定兩步,**順序不可調換**:先 scp 回 `~/pcap/` 並確認檔案在、大小合理,
   **才** `rm -f /tmp/*.pcap /tmp/*.err`。有背景任務還在寫 `/tmp` 時不要清。
2. 檔名格式(使用者指定):`<測試日期>-<feature>-<image build date>.pcapng`,
   例 `2026-08-12-evtPort-A-2026_0812_1136.pcapng`。
3. **一定要連同名 `.tcpdump.log` sidecar 一起帶。** 它的價值在**結尾摘要**那行
   (`N packets captured / 0 packets dropped by kernel`)—— 那才證明**無遺漏**。
   只有起始行(`tcpdump: listening on lo, ...`)的 sidecar 只證明**擷取有啟動**,
   兩者強度差很多。
4. ⚠️ **已知腳本缺陷**:結尾摘要是 tcpdump **退出時**才印,而腳本在它完全退出前就 scp 了,
   所以 sidecar 常是殘缺的。scp `.err` 之前要確認 tcpdump 已結束。
5. 空的 pcap(0 packets)**不等於沒證據** —— 但要另外附結構性佐證。例:mainline 那份
   0 packets,搭配 `ss` 顯示 `:705` 連 listener 都沒有,比 sidecar 更強。

相關:[[feedback_cross_session_handoff_discipline]]、[[project_getfwd_probe_must_be_wire_verified]]、
[[project_measure_snmp_walk_skill_defects]]、[[feedback_dut_operation_authorization]]
