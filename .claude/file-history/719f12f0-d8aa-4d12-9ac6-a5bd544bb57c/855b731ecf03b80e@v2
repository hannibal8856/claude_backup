---
name: snmp-walk-slow-diagnosis
description: "SNMP walk 慢的診斷手法 — 先用 snmpget vs snmpgetnext 分辨「讀值慢」還是「GETNEXT 慢」,再抓 AgentX loopback pcap"
metadata: 
  node_type: memory
  type: project
  originSessionId: 719f12f0-d8aa-4d12-9ac6-a5bd544bb57c
  modified: 2026-07-29T08:23:02.322Z
---

MXNOS framework AgentX subagent 若 `snmpwalk` 卡頓,**不要先假設是資料讀取路徑**。2026-07-29 曾為此連續修錯兩輪方向(ADR-0007 改走 REST、ADR-0008 改 hybrid),兩者最後都 revert。

**分辨步驟(成本低、極有效):**

1. **單發 `snmpget` 打那個「看起來慢」的 OID**。若 ~10ms → 讀值路徑沒問題,別再動 config/status 讀取。
2. **`snmpgetnext` 打同一個 OID 的前一個**。若秒級 → 問題在 GETNEXT。
3. **對照組**:連續已註冊 OID 之間的 getnext(應 ~15ms) vs 跨未註冊區間的 getnext(慢) → 確認是「跨 gap」。
4. **抓 AgentX loopback pcap 看 master↔subagent**(外部 :161 的 pcap 看不到):
   `tcpdump -i lo -s0 -w /tmp/agentx.pcap port 705`,再用
   `tshark -r x.pcap -d tcp.port==705,agentx -Y agentx` 分析。
   數「一個 client 請求觸發幾次 master→subagent GetNext-PDU」。

**已知根因(已修,見 ADR-0009):** framework 用 `register_instance` 逐 OID 註冊 → 每個 OID 自成 AgentX subtree → GETNEXT 跨 gap 時 master 逐一 probe,每次一個 round-trip(實測 18 次 × 0.107s = 3.9s)。解法為 subtree 註冊 + framework 自行回答 GETNEXT 並在 in-process 迴圈跳過無值 OID。

**Why:** walk 慢有兩個完全不同的來源(取值 vs OID 尋訪),外顯症狀相同(client 1 秒逾時重送),但修法南轅北轍。跳過步驟 1-2 就會像那兩輪一樣改錯層。

**How to apply:** 遇到任何 MXNOS SNMP 效能問題,先跑步驟 1-2 再決定方向。另注意 tshark 對 AgentX response 常標 `[Malformed Packet]`(dissector 限制),不代表封包真的壞掉。相關:[[project_plan_e_iss0_get_forward]]、[[project_mxipif_col2_inmaster_deferred]]、[[project_plan_c_agentx_set_path_and_framing]]。
