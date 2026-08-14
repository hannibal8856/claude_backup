---
name: project_mxqos_forwarding_measured_slower
description: "mxQos 轉發到 ISS 比 in-master 慢 14%,結論是不要搬;in-master 每請求重建連線卻仍較快,瓶頸在 ISS 端"
metadata: 
  node_type: memory
  type: project
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T05:52:20.210Z
---

2026-08-13 在乾淨 image `2026_0813_0905`(GETFWD trace 已編譯期關閉)上量到。

## 數字

同一顆 image,只切換 `/etc/moxa/netsnmp/agentx_owned.list` 的 `mxqosdb/ +getfwd +nodelegate`
一行(bind mount)+ 重啟 snmpd,七張表逐表 walk、每表 7 次取中位數:

```
A(未列入,in-master)  A1 1.4033s   A2 1.4117s    重複性 0.008s
B(+getfwd +nodelegate) B1 1.6144s   B2 1.5960s    重複性 0.018s
Δ = +0.197s (+14.0%)   ← 雜訊的 11–25 倍
```

慢的集中在資料量大的三張:`.1.5` +21.8%、`.1.6` +19.0%、`.1.7` +18.0%;
`.1.1`(64 vb)幾乎零差異。**完整性兩臂完全相同**(434 varbinds,七表逐表一致)。

**→ 結論:不要搬 mxQos。** 這是交接預留的「機制成立 ≠ 值得用」那個分支。

## 對照有效(兩張 pcap 都在 `~/pcap/2026-08-13-mxqos-arm{A,B}-*`,含 sidecar)

```
A  2 GetNext(邊界流量)/ 6 次 .8691.603 位元組 / 1.6 KB
B  201 GetNext / 205 Response / 608 次 / 70 KB
```

100 倍差距,`+getfwd` 確實在轉發 —— 這推翻了「B 臂沒轉發所以才慢」的中途假說。

## 反直覺的地方(值得再追)

in-master 走 `ies_uri_handle_client` → LibFrameworkUri,而它 **每個請求重建 TCP 連線**
(見 [[project_frameworkuri_reconnects_per_request]]);AgentX 是開機建一次的常駐連線。
**結構上 in-master 該比較慢,實測卻快 14%。**

→ 代表 **ISS 回答一個 varbind 的時間,超過「framework URI 建連 + 讀取」的總和**。
瓶頸在 ISS 那一端,不在傳輸層。這是「委派給 ISS 能加速」這個前提的反例,
不只適用於 mxQos —— 任何「本地讀取已經夠快」的群組都可能是負收益。

相關:[[project_getfwd_noop_on_mxportdb_stdethdb]]、[[feedback_verify_completeness_and_perf]]、
[[project_mxqos_getnext_boundary_bug]]
