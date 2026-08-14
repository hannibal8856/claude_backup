---
name: feedback_ask_what_you_held_fixed
description: 下結論前先問「我把什麼固定住了」;兩臂相同的那一格正是量測看不見的地方
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 543288d9-63d4-40ca-a311-1a8b83f5414d
  modified: 2026-08-13T08:37:39.632Z
---

2026-08-13 mxQos 那輪的教訓。**這一類錯誤與工具缺陷不同,所有品質檢查都會通過。**

## 發生了什麼

我對 mxQos 做了一組執行無誤的 A/B:交錯 A/B/A、雙向 pcap 對照、重複性 0.008s / 0.018s、
差異是雜訊的 11–25 倍。**數據無誤、方法無誤,結論仍然錯。**

- 我只量了 **連續 walk** 形狀 —— 那把具象化成本攤在大量 varbind 上,**結構上最有利於
  in-master**。真實使用者是 table view 形狀,那裡具象化佔 60–71%,**結論可能相反**。
- 更嚴重:兩臂**都**把 registration 留在 in-master(`+nodelegate` 的定義),
  所以那個「walk 只回 17%」的邊界缺陷**在兩臂都存在** ——
  **價值最大的變數被固定住了**,然後我在剩下的變數上做了很漂亮的 A/B。

## Why

前面那類陷阱(空 pcap、逾時常數、死標籤、walk 中止)的共同點是**輸出可疑**,
可以靠檢查工具擋下來。這一類**輸出完全可信** —— 品質檢查檢的是「這個數字對不對」,
**不是「這個數字回答的是不是我要問的問題」**。

## How to apply

下結論前問兩個問題:

1. **「我把什麼固定住了?」**(`document 4` 的提法,比下面那條好操作)
   → 直接看 A/B 表:**兩臂相同的那些欄位,就是這組量測看不見的東西**。
   它們不會出現在任何一張比較表上,因為兩邊一樣 —— 所以要主動去列。
2. **「換一種合理的使用形狀,這個結論會不會反過來?」**
   → 若會,**結論的作用域只到那個形狀為止**,不能寫成「這個群組不值得搬」。

寫結論時把作用域寫進句子:「在連續 walk 形狀下,轉發慢 14%」是對的;
「mxQos 不值得搬」是錯的 —— 同樣的數據,後者多宣稱了兩個未測的維度。

相關:[[feedback_absence_claims_need_reach_proof]]、[[feedback_verify_completeness_and_perf]]、
[[project_mxqos_forwarding_measured_slower]]
