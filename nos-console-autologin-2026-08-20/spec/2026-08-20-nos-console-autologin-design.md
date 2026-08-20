# Spec — 將 buildroot-console-autologin 收進 nos-cc-skill (as `nos-console-autologin`)

狀態:已核可(2026-08-20)。存放於 `~/NOS_v7.0_develop/buildroot/claude_docs/`,
不屬於 nos-cc-skill repo,在 buildroot 樹中亦為 untracked —— 僅為本次 MR 的實作依據。
durable 內容的歸屬:設計決策 → `docs/adr/0007-*`;變更敘述 → MR 描述;用法 → SKILL.md + README。

## 目標

把目前住在 `~/.claude/skills/buildroot-console-autologin/` 的個人 skill
(SKILL.md 165 行 + `scripts/probe.py` 174 行)收進 nos-cc-skill plugin,
以 merge request 形式送審。

## 決策(Q&A 已定案)

| # | 決策 | 選擇 |
|---|---|---|
| 1 | 目錄/skill 名稱 | `nos-console-autologin`(對齊 repo 全 `nos-` 前綴) |
| 2 | probe.py 測試深度 | 中等:純函式 + 三棵合成樹的 subprocess 冒煙;**不重構 probe.py** |
| 3 | SKILL.md 改寫幅度 | 最小三處 + 保留可攜版告誡;**不拆 references/** |
| 4 | 書面決策 | 寫 ADR-0007 + README dev-only 標記 |
| 5 | MR 流程 | issue-first,glab + `~/moxa_gitlab_scm_token` |

## 交付內容

```
skills/nos-console-autologin/
  SKILL.md                        # 由 165 行原檔改寫(三處)
  scripts/probe.py                # 原封不動搬入
tests/test_console_autologin.py   # 新增
docs/adr/0007-console-autologin-prose-gate.md   # 新增
README.md                         # 表格一列 + usage 一節 + dev-only 標記
.claude-plugin/plugin.json        # 1.16.1 → 1.17.0,description 補上 console autologin
.claude-plugin/marketplace.json   # 1.16.1 → 1.17.0,兩處(metadata.version + plugins[0].version)
```

新 skill = minor bump(CLAUDE.md semver 規則)。兩個 json 版本必須同步。

**不動**:`CLAUDE.md` 的 structure tree(它只列 5 個 skill,實際 15 個 —— 既有過期,
不在本次範圍;屬於 "Surgical Changes" 的 pre-existing 問題,回報但不修)。

## SKILL.md 改寫點(僅三處,其餘逐字保留)

1. frontmatter `name:` → `nos-console-autologin`
2. Step 1 指令 → `python3 ${CLAUDE_PLUGIN_ROOT}/skills/nos-console-autologin/scripts/probe.py [path]`
3. Step 1 尾端 `> Local trap:` 區塊 → 改為不指涉特定機器的通則:

   > 存在性主張一律以 probe(`python3`)的輸出為準。**不要**用 `ls` / `grep`
   > 去「二次確認」probe 的結果 —— 操作者環境可能有 wrapper 改寫 shell 輸出。

`ttyPS0` / `ttyS1` / `admin` / `moxash` / `/bin/zsh` **保留**:Moxa 樹的領域知識,
是本 plugin 該擁有的內容,不是外部依賴。

原檔第 2 處是硬 gate:`grep -r '~/.claude/' skills/` 必須為空(pre-commit hook 強制)。
原檔第 3 處是 CLAUDE.md Boundary 原則(shipped skill 不得依賴它不擁有的東西)。

## 測試設計 — `tests/test_console_autologin.py`

沿用 `tests/conftest.py` 既有 fixture 風格。

**層一:純函式**
- `find_root` —— 從深層子目錄往上走,命中同時有 `package/` 與 `Makefile` 的目錄;
  走到檔案系統根仍找不到時,先讀 probe.py 確認其實際行為,再以測試把該行為固定為
  契約(本 MR 不改 probe.py 的行為)
- `read_config` —— 讀 `.config`,不是 defconfig
- `cfg` —— 取值、預設值、引號剝除

**層二:subprocess 冒煙**(`tmp_path` 建合成樹,跑 probe.py,斷言判讀行)

| 樹 | 內容 | 斷言 |
|---|---|---|
| systemd | `BR2_INIT_SYSTEMD=y`、getty port `ttyS0`、`BR2_TARGET_ROOTFS_SQUASHFS=y`;`output/target/lib/systemd/system/serial-getty@.service`、`output/target/sbin/agetty` | init system / getty port / read-only 三行判讀正確 |
| busybox | `BR2_INIT_BUSYBOX=y`、getty port `ttyPS0`;`output/target/sbin/getty` | 走 3b 路徑;port 不是硬編 `ttyS0` |
| 無 build | 只有 `.config`,無 `output/target/` | 明講哪些檢查 pending;不 crash、不假裝通過 |

第三棵是重點:SKILL.md 承諾「config 半邊仍可用,要說出哪些檢查待建置」,
那是個會被靜默違反的行為契約。

## ADR-0007 — Console autologin 以 prose safety-gate 把關,不做機械性 refuse

- **Context** —— 本 plugin 第一個會降低安全性的 skill;現行防線全是 SKILL.md 的
  四條 prose gate,靠 AI operator 自律。
- **Decision** —— 收進來。把關由三件事組成:四條 safety gate、`MOXA-DEV-AUTOLOGIN`
  marker(可 grep 回收)、overlay-first 交付順序(不碰共用 post-build script)。
- **Rejected**
  - *維持個人 skill* —— 知識散在個人環境,每次重推導;而 probe 的 per-tree 判讀
    正是最容易憑記憶弄錯的部分。
  - *偵測到 CI/release defconfig 就硬性 refuse* —— probe 只讀 `.config`,無法可靠
    分辨哪個 config 是 release 用的;誤判時硬 refuse 會擋掉合法用途,而
    marker + 明確同意已讓風險可見且可回收。
- **Consequences** —— 沒有機械保證,依賴 operator 遵守;回收性完全押在 marker 上,
  因此「每個寫出的檔案都帶 marker」升級為不可協商。

## 執行順序

```
0. ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit   # 目前未安裝
1. glab issue create → 預期 #12「Add nos-console-autologin skill」
2. git checkout -b 12-nos-console-autologin
3. commits(無 Co-Authored-By):
     feat: add nos-console-autologin skill           # skills/ + README(含表格列、usage 節、
                                                     #   dev-only 標記)+ 兩個 version bump
     test: cover nos-console-autologin probe         # tests/
     docs: add ADR-0007 console autologin prose gate # docs/adr/
4. Gate A —— pytest tests/ 全過;grep -r '~/.claude/' skills/ 為空
5. Gate B —— 照 SKILL.md 逐步走一遍:${CLAUDE_PLUGIN_ROOT} 展開後檔案真的在、
   probe 輸出真的餵得進 Step 2 決策、Step 5 驗證指令路徑正確
6. git push -u origin 12-nos-console-autologin
7. glab mr create,描述 link #12
```

Token 處置:`~/moxa_gitlab_scm_token`(mode 600),用時以 `python3` 抽
`glpat-[A-Za-z0-9._-]+` 注入環境變數,不落地、不列印、不寫入 glab config。

## 收尾(merge 後,不屬於本 MR)

- `/plugin update nos-cc-skill`,在真的 buildroot 樹觸發一次,確認 skill 載得到、probe 跑得動。
- 刪除個人副本 `~/.claude/skills/buildroot-console-autologin/`:個人 skill 優先於
  plugin skill,留著會讓 plugin 版永遠不被觸發,且兩份會分岔。由使用者決定。

## 成功判準

1. `pytest tests/` 全過(含新的 `test_console_autologin.py`)→ 驗證:退出碼 0
2. `grep -r '~/.claude/' skills/` 無輸出 → 驗證:退出碼 1
3. `test_shipped_self_contained.py` 對新檔案通過 → 驗證:該測試檔綠燈
4. 兩個 json 的 version 一致且為 1.17.0 → 驗證:python 讀出比對
5. MR 在 GitLab 上開起來且 link 到 issue → 驗證:`glab mr view`
