---
name: project_frameworkuri_reconnects_per_request
description: "LibFrameworkUri 每次 URI 請求都 close+重建 TCP 連線;_isConnectionAlive() 硬編回傳 0,快取的 handle 只省 malloc 不省握手"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac72d867-b88f-4f5f-9331-a1243ef368f8
  modified: 2026-08-11T10:12:24.375Z
---

`lib_moxa_framework_uri/src/lib_framework_uri.c` 是手刻的 HTTP client(raw `AF_INET` socket,
非 libcurl)。`_isConnectionAlive()`(`:98-105`)**硬編 `return 0`**,原始註解說明這是
「force reopen a socket per request」的暫時作法(因為 `recv(MSG_PEEK)` 對 HTTP server 永遠判定為死)。
呼叫端 `:253` 因此每次都 `_closeConnection()` → `_openConnection()`。

每次 URI 讀取 = `socket()` + `connect()` + `send()` + `recv()` + `close()`,
路徑 `snmpd → 127.0.0.1:80 (nginx) → 9759 (actix)`。請求是 HTTP/1.1 且沒送 `Connection: close`
(`:122`),**nginx 願意保持連線,是 client 主動丟掉的**。

影響:in-master `ies-auto-mibs`(`moxa_snmp_handle_util.c:1041` 等 6 處)與 dlmod plugin
(`lib_moxa_snmp_plugin.c:144`)兩條路都中。**不影響** framework subagent(in-process)。

**Why:** `gUriHandle` 這類「快取的 handle」給人已經重用連線的錯覺,實際只省下 buffer 的 malloc。
即使 fork/exec 全部消除,每個 URI 讀取底下仍埋著一次完整的 loopback TCP 建連。
對照組:AgentX 把同一件事做對了 —— `snxtrans.c:151/:217` 開機建一次、全域保留,
這也是「AgentX 走 TCP 不比 proxy UDP 慢」的一半原因。

**How to apply:** 討論 URI 讀取延遲時要把這一項算進去,但**在量到數字之前不要對外給延遲數值**
(`strace -c -e trace=socket,connect,close` 取次數、`-T` 取單次耗時)。此項**不在** Vincent
《3rdparty_net_snmp enhancement》的六個瓶頸內,引用時要標示出處差異 —— 見 [[project_vincent_proposal_evaluation]]。
最先該試的修法是把 keep-alive 修好(只動 `_isConnectionAlive()` 與 `:253`,不需他人配合)。
