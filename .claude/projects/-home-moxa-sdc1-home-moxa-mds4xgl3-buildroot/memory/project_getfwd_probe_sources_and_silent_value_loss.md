---
name: project-getfwd-probe-sources-and-silent-value-loss
description: "+getfwd 的 probe 可用 ISS 註冊的 MIB root;forward_get_to_iss 無條件回報成功,挑錯對象會靜默掉值(mxlldp 2026-08-14 實地掉 25 vb);撤回的 runtime 檢查靠 !request->delegated 可救回同步那半"
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fbf478-f4fe-4f9b-b738-eb5019b102dd
  modified: 2026-08-14T01:17:35.958Z
---

## 急迫性修正(2026-08-12,ADR-0030 之後)

本檔原本假定 `mxportdb/` / `stdethdb/` 的 `+getfwd` 是壞的(依 ADR-0025)。**那個前提已被推翻** ——
ADR-0030 用封包證實**四個前綴都正常轉發**,也就是說 **ISS 確實服務那些 OID**,
所以**現況沒有在丟值**。

→ 下面的缺陷從「正在流血」降級為「**潛在風險**」。程式碼沒有變,缺陷仍然存在,
但它現在是**加新前綴前必須先架好的安全網**,不是要立刻搶修的線上故障。
判斷加不加它的優先序時,請用這個修正後的定位。

## 🔴 再次升級(2026-08-14):已實地掉值,不再是潛在風險

`snmp-plan-E reopen 7` 對 `mxlldp/` 下 `+getfwd +nodelegate` 後,**整支 MIB 消失**:
`walk .603.5.1` → No Such Object、逐欄 GET 全部 No Such Object、
**線路上 `.603.5.1` 位元組 0 次**、25 個 varbind 歸零、**無任何錯誤訊息**。

成因是三個缺陷串聯(2026-08-14 由 `trace 3` 從原始碼確認):

1. `mox_snmp_probe_derive`(`ies_auto_mibs.c:3325`)的走訪下限是 `len >= 3`,
   **可以一路走到 `.1.3.6`**,遠高於該 group 自己的 MIB
2. `mox_snmp_reg_is_local`(`:3265`)只檢查 handler chain 裡有沒有
   `mox_snmp_handle_entry`,即**只排除「我方」,不要求「是 subagent」** ——
   同行程內任何別的 handler(net-snmp 內建 MIB module、dlmod 外掛…)都會被放行
3. **`return 0` 無條件**(見下節)—— 把「挑錯對象」變成「靜默掉值」

→ 被挑中的本機 handler **同步**回 noSuchObject,**所以線路上一個封包都沒有**。
「0 個封包」在這裡不代表「沒有轉發」,而是「轉發到了行程內的錯對象」。

**`+nodelegate` 沒有任何緩解作用** —— 它只對 RO entry 有意義,
見 [[project_zero_ro_prefix_list_is_noop]]。

## ⚠️ 必修缺陷:轉發後不檢查回應,值會靜默消失

`ies_auto_mibs.c` 的 `mox_snmp_forward_get_to_iss()`:

```c
netsnmp_call_handlers(iss_sub->reginfo, reqinfo, request);
return 0;                    // ← 只確認 handler 被呼叫,不看 ISS 回了什麼
```

呼叫端拿到 0 就 `return SNMP_ERR_NOERROR`。所以 **ISS 若不服務該 OID,回 noSuchObject,
in-master 照樣回報成功** → 那個 OID 從「本地讀得到正確值」變成消失,且無任何錯誤訊息。

### 🔴 我原本提的修法是錯的(2026-08-12 撤回)

原提案:「`netsnmp_call_handlers()` 之後檢查 varbind 是否為 `noSuchObject`,是的話 `return -1`
退回本地」。**不可行,而且會做出一個假的安全網。**

由 `snmp-plan-E reopen 6` 指出、我查證後確認:**AgentX 轉發是非同步的**。
`ies_auto_mibs.c:3174-3177` 的註解自己就寫著 "marks the request delegated and sends it async;
net-snmp fills the value when ISS replies"。所以呼叫後那一行讀到的 varbind **尚未填值**,
檢查恆為「看起來沒問題」—— 這正是本專案反覆出現的「工具沒運作與假說成立長得一樣」的形狀。

**而且回應階段沒有可用的掛鉤點。** 實際填值在 net-snmp 自己的
`agent/mibgroup/agentx/master.c` `agentx_got_response()`(`:375-425`)裡:

```c
for (var = pdu->variables, request = requests; request && var; ...) {
    if (var->type != SNMP_ENDOFMIBVIEW)
        snmp_set_var_typed_value(request->requestvb, var->type, ...);
    request->delegated = REQUEST_IS_NOT_DELEGATED;
}
```

**原本的 in-master handler 不會被重新進入**,沒有 per-request callback。要做 runtime 退回
就得改 net-snmp 本體,或把已離開 handler chain、且 asp 已在 `agent_delegated_list` 上的 request
重新注入 —— 兩者成本都遠高於收益。

### ✅ 撤回範圍過寬,2026-08-14 部分翻案 —— 同步那半救得回來

上面的撤回**對「真的走了 AgentX」那一半成立,但範圍過寬**,把同步那一半一起丟了 ——
**偏偏同步那半才是會靜默掉值的那個**(mxlldp 就是,見上節)。

兩者可以判別。net-snmp 的 AgentX master 把請求送給 subagent 時會呼叫
`netsnmp_handler_mark_requests_as_delegated(requests, REQUEST_IS_DELEGATED)`
(`net-snmp-5.9.3/agent/mibgroup/agentx/master.c:238,280`),回應回來才設
`REQUEST_IS_NOT_DELEGATED`(`:355,399,420`)。所以在 `netsnmp_call_handlers()`
**返回的當下**:

| `request->delegated` | 意義 | 能不能檢查 varbind |
|---|---|---|
| 已設定 | 真的走 AgentX,答案稍後才到 | **不能** —— 這才是原撤回的正當範圍 |
| 仍是 0 | **同步答完,是本機 handler 答的** | **可以,答案已經在裡面** |

提案(2026-08-14 交給 `reopen 7` 實作,**未實作、未測試**):

```c
    (void) netsnmp_call_handlers(iss_sub->reginfo, reqinfo, request);
    request->next = saved_next;
    if ( !request->delegated &&
         ( request->requestvb->type == SNMP_NOSUCHOBJECT ||
           request->requestvb->type == SNMP_NOSUCHINSTANCE ) )
    {
        return -1;              /* 退回本地讀取,最壞只是沒有加速 */
    }
    return 0;
```

搭配第二個修法(**推導下限 = 該 group 自己的 OID root**,由該 list 前綴底下所有 entry 的
最長共同 OID 前綴算出)。兩者互補:前者從源頭不讓它挑錯對象,後者保證挑錯了也不掉值。
**只有後者能把 ADR-0031 的宣稱(「最壞是沒有加速,不會掉值」)變成程式碼保證。**

⚠️ **不要再引用上面那條撤回去否決整個 runtime 檢查** —— 它只否決得了 `delegated` 那一半。

### 修法設計定案(2026-08-14 `trace 3` review,三個都要做)

**A、下限、B 是正交的,少任何一個都留下掉值路徑。**

| 修法 | 擋住 | 擋不住 |
|---|---|---|
| **A** 肯定測試 | 撞到非 subagent 的本機 handler | 撞到錯的 subagent / 錯的 MIB root |
| **下限** | 走出自己 MIB 之外 | 同一 MIB 內 ISS 不服務的欄 |
| **B** `!delegated` + 錯誤檢查 | **同步**回錯(含 `myvoid==NULL`) | **非同步**回 noSuchObject |

**A(肯定測試)**:別再問「是不是我方」,直接問「是不是 subagent」。
每個 subagent 註冊的 subtree 都帶 `access_method == agentx_master_handler`,
且 `handler->myvoid` = 該 subagent 的 `netsnmp_session *`
(`agentx/master_admin.c:223,232`)。
- ✅ 函式指標比對可靠:`master_admin.c:229` 的 `/* fake it */` 宣告
  `HANDLER_CAN_GETBULK`,正是為了躲掉 `agent_handler.c:300-303` 的 `bulk_to_next`
  注入,所以 chain 只有一個節點;就算被注入,`inject_handler_before` 是前插、
  `inject_handler_into_subtree` 插的是複本,都不動原節點的 `access_method`。
- ✅ **連結相依:已查證,不是問題**(2026-08-14 `reopen 7` 實查本 build)。
  `libnetsnmpmibs.so` 的 `NEEDED` 已含 `libnetsnmpagent.so.40`、已有 49 個未定義
  `netsnmp_*` 符號從那裡解析,而 `agentx_master_handler` 是該 `.so` 的匯出動態符號
  (`nm -D` 命中)。**引用它不新增任何連結相依,不需要 guard。**
  界線:只驗了這個 build,其他機種組態未查。
  ⚠️ 查法陷阱:`nm`/`strings` 對 **`snmpd` 與 `libnetsnmpmibs.so` 都回 0** ——
  符號在 `libnetsnmpagent.so`。查錯對象會得到「AgentX master 沒編進去」這個
  與事實相反的結論(`reopen 7` 當天才剛抓到 AgentX 封包)。又一次
  [[feedback_absence_claims_need_reach_proof]]。
- ⚠️ **不要快取 `myvoid`**,每次重新解析。現有 `gAgentXDerived[]` 存的是 OID,安全;別把 `sess` 一起存。

**🔴 B 是必要的,不是縱深防禦。** A 擋不住這條:

```c
/* agentx/master.c:443 agentx_master_handler */
:448  netsnmp_session *ax_session = (netsnmp_session *) handler->myvoid;
:458  if (!ax_session) {
:459      netsnmp_set_request_error(reqinfo, requests, SNMP_ERR_GENERR);
:460      return SNMP_ERR_NOERROR;      /* 同步返回,delegated 從未設定 */
      }
```

貨真價實的 AgentX registration(A 會放行),但 session 為 NULL 時同步回錯 →
我們 `return 0` 當成成功 → 值消失。
⚠️ 因此 **B 的條件不能只檢查 `NOSUCHOBJECT`/`NOSUCHINSTANCE` 型別** ——
那條走的是 `SNMP_ERR_GENERR`(錯誤狀態,未必改 varbind type)。要放寬成
「`!delegated` 且(有錯誤狀態 或 varbind 仍 `ASN_NULL` 或是例外型別)」。
⚠️ 退回本地前**必須清掉失敗轉發留下的錯誤狀態**,否則本地讀到的正確值會被
error-status 蓋掉。(`netsnmp_set_request_error` 實際設哪個欄位**未釘到**,實作時確認。)

**下限不可省。** A 只保證「是 subagent」,不保證「服務這個 OID」;走太高會撞到
另一個 subagent 或同一 subagent 的別的 MIB root,那時請求**真的走 AgentX**、
`delegated` 會被設、**B 不觸發**,靜默掉值原樣回來。
成本只要 `static int gAgentXRootLen[AGENTX_OWNED_MAX]`(該 group 的最長共同 OID
前綴長度,註冊期算一次),**不需要新的 OID 陣列**。

**三者都補不掉的殘餘風險**:轉給對的 subagent、但它不服務該 OID、非同步回
noSuchObject。只能靠事前 ISS 涵蓋篩選 + 事後完整性 gate。
→ **請在 ADR 明寫成已知殘餘風險**,不要再讓 ADR-0031 的宣稱比實際強。

### 改採的立場(2026-08-12,已被上一節部分取代):安全網留在驗收階段

`walkdiff.py` 的 `missing` 本來就進 exit code,**它已經能抓到「ISS 不服務導致欄位消失」**。
正確的做法是把規則講明確 —— **加任何新前綴都必須對 oracle 做完整性比對** ——
而不是加 runtime 機制。見 [[feedback_verify_completeness_and_perf]]。

搭配的診斷手段是 `+getfwd` 的 trace(T2/T3/T4),它能直接指出某個欄位有沒有被轉發。

這是 `+getfwd` 唯一的安全網缺口。目前擋住它的只有人工的完整性驗收
(ADR-0024 對 mxRstp 驗了 27 欄 / 227 varbind 不變),見 [[feedback_verify_completeness_and_perf]]。

## probe 不必是「被委派的 RO 欄」—— 可以是 ISS 註冊的 MIB root

ISS 的 AgentX 註冊機制(`app_moxa_iss_10_1_0/code/future/snmpv3/snxmain.c:870` `SnxMainRegisterMibs()`):

- 走訪 `gpMibReg`(由各模組的 `SNMPRegisterMibWithLock(&xxxOID, ...)` 填),
  對每個 MIB 的 **root OID** 送 AgentX Register PDU(`SnxMainRegOrUnRegOid(..., ~SNX_INSTANCE_REGISTRATION)`)
- 特例:`.1.3.6.1.6`(SNMPv2)跳過;`.1.3.6.1.4.1.2076`(SNX_PROP_MIBID_1)**刻意不註冊**
  (註解:NOS7 不暴露這棵 ~5k OID 的 ISS 私有樹);`.1.3.6.1.4.1.29601.2` 註冊一次後
  底下其他 MIB 全部略過
- `:949-967` 有「root 已註冊就跳過子層」的去重,但那是**單一插槽**(只比對前一個註冊過的 root),
  依賴 `gpMibReg` 已按字典序排列(`:894` 註解自承)

→ **ISS 註冊的是「區段」不是「單一 OID」。** 所以區段內任何 in-master 沒搶走的 OID,
`netsnmp_subtree_find()` 都會解析到 ISS —— 包含 table-entry OID、甚至 MIB root 本身
(`ies_auto_mibs.c:3096-3097` 的註解就是這個意思)。

**實務意義**:0 RO 的前綴(全 RW,現行 11 個:`mxqosdb/` 29、`stdlldp/` 8、`mxradiusdb/` 7、
`mxlldp/` 6、`fscfadb/` 4、`mxrlpsdb/` 4、`mxstcldb/` 3、`mxvlan/` 3、`stdot1lldp/` 2、
`fsvlandb/` 1、`stdot3lldp/` 1)**當時**拿不到 probe(候選只來自被委派的 RO entry)→
`+getfwd` 結構上無效。

🔴 **這一段已過時(2026-08-14)。** 推導功能(`3rdparty_net_snmp 5061248`
"Let +getfwd reach prefixes with no delegated RO entry")之後,0-RO 前綴**會自動
往上找非本地祖先當 probe**,所以 `+getfwd` **對全 RW 前綴確實會生效** ——
`reopen 7` 實測 `mxstcldb/`、`mxrlpsdb/` 轉發成功(76 個 GetNext PDU、
OID 位元組 122 / 90 次,正負對照皆成立)。

**但「會生效」不等於「有效益」,而且推導本身就是掉值的來源**(見本檔上方三個缺陷)。
另外顯式 `probe=<oid>` 仍可用且**優先於推導**(`ies_auto_mibs.c:3363`
"It wins over everything else … the escape hatch for whatever derivation cannot reach",
`mox_snmp_probe_for_entry` 第一件事就查它並立即 return,trace 是 `T2 LISTED`)。
⚠️ probe **只決定「交給哪個 registration」,請求帶的仍是原始 OID** ——
指向「ISS 有註冊但不涵蓋目標 OID」的位置就會 noSuchObject 掉值,
所以 ISS 根本沒有該 root 的前綴(如 `mxlldp/`)**沒有安全的 probe 可指**。

**How to apply:** 想讓 0-RO 前綴支援 `+getfwd`,順序是
① 先確認 ISS 真的**服務**(不只宣告)那段 OID —— 見 [[project_iss_coverage_screen_before_delegating]];
② 再把上面那個「檢查回應」的修正做掉,否則 ISS 答不出來時值會消失;
③ 最後才談 probe 要寫在 code 還是 `agentx_owned.list`。
**順序顛倒的話,第一個症狀就是 OID 消失而且查不到原因。**
相關:[[project_getfwd_noop_on_mxportdb_stdethdb]]、[[project_iss_agentx_two_registrations_getnextindex]]
