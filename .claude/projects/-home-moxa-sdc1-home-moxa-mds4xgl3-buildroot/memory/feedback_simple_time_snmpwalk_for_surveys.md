---
name: feedback_simple_time_snmpwalk_for_surveys
description: "完整性普查用 `time /usr/bin/snmpwalk <root>` 就夠,不要套 measure-snmp-walk 的重型協定;那套是給 A/B 效能與 AgentX 繞徑判定用的"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bdcc4d2c-9721-438a-afe2-8482c5b0ae9b
  modified: 2026-08-13T09:42:00.872Z
---

使用者 2026-08-13 明示:**「以後其實這樣測就好」** —— 指的是最樸素的

```bash
time /usr/bin/snmpwalk -v2c -c public 192.168.127.253 <root-oid>
```

**Why:** 那天我為了「walk 這幾個 subtree 看哪個形狀比較完整」載入了
`measure-snmp-walk` skill,跑 3 reps、寫 probe/reps 腳本、逐欄 GETNEXT 反證。
結論**與使用者自己手打七行 `time snmpwalk` 完全一致**(0.195/0.282/0.334/0.683/
0.393/0.096/0.149 秒,對我的 0.20/0.29/0.35/0.70/0.43/0.02/0.15)。
對「有沒有資料、幾欄、多久、會不會中止」這種問題,重型協定沒有帶來額外資訊。

**How to apply:**

- **普查 / 探路 / 「這支有沒有東西」** → 直接 `time /usr/bin/snmpwalk`,一次就好。
  中止與否看 stderr 的 `Error in packet`,完整性看欄位分佈。
- **仍然要用 [[project_measure_snmp_walk_skill_defects]] 那套重型協定的場合**,
  只有兩種:
  1. 結論形如「A 比 B 快/慢」→ 需要交錯 A/B/A + 中位數(漂移曾達 7.5%)
  2. 結論形如「這組有沒有走 AgentX」→ 需要 pcap + 正/負對照
- `/usr/bin` 絕對路徑仍是硬性的([[project_pysnmp_shadows_snmpwalk]]),這條沒有放寬。
- 反證用的逐欄 `snmpgetnext` 仍有價值 —— 它是分辨「整欄被 walk 跳過」與「真的沒資料」
  的唯一辦法,普查時若看到欄位數對不上定義才需要出動。

相關:[[feedback_absence_claims_need_reach_proof]]
