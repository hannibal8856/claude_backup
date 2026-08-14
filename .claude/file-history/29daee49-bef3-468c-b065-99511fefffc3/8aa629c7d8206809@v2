---
name: project-build-tree-and-container
description: "Plan E 有兩棵樹兩條分支;建置要用 mx_mds4xgl3 容器 + ~/mds4xgl3,make target 不帶 -custom,最後卡 HSM 簽章由使用者跑"
metadata: 
  node_type: memory
  type: project
  originSessionId: 13f6131f-3289-46a0-9662-a2a36f544e35
  modified: 2026-08-09T09:56:41.883Z
---

**兩棵樹、兩條分支,別搞混:**

| 路徑 | branch | 狀態 |
|---|---|---|
| `~/mds4xgl3` | `snmp-plan-E` | **現行方向**,所有 ADR-0011/0012/0013 的工作都在這 |
| `~/SNMP_PLAN_E2`(2026-08-06 由 `~/SNMP_PLAN_E` 改名) | `snmp-plan-E2` | 已擱置 |

`snmp-plan-E2` 用 namelen 做 AgentX dispatching、依「D1」刪掉 `agentx_owned.list`
(commit `8ceffee`),使用者判定 latency 不佳、走過同樣的坑,暫時不玩。

**建置容器**:`docker start mx_mds4xgl3`(掛 `~/mds4xgl3`,workdir = repo 根)。
`mx_SNMP_PLAN_E` 已停止且**無法再用**(bind mount 來源路徑已改名)。

⚠️ **一定要用 `bash -c`,絕對不要用 `bash -lc`。** 2026-08-09 實測:

```
docker exec mx_mds4xgl3 bash -c  'echo $PATH'
  /home/moxa/.local/bin:/home/moxa/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
docker exec mx_mds4xgl3 bash -lc 'echo $PATH'
  /home/moxa/.cargo/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
```

login shell 重讀 `/etc/profile`,把 `~/.local/bin`(以及 `/usr/local/sbin`、`/usr/sbin`、`/sbin`)
洗掉。HSM 簽章腳本需要 `~/.local/bin/scm`,用 `-lc` 會在
`trigger_ci_hsm_sign.sh:219` 噴 **`scm: command not found`** → `scm upload failed`
→ `cp: cannot stat 'hsm_download_files/signed/*'` → `target-post-image` Error 1。
**症狀看起來像簽章服務有問題,其實只是 PATH。** 換成 `bash -c` 重跑同一個 `make` 就過了。

**make target 不帶 `-custom`** —— `output/build/xxx-custom` 的 `-custom` 是 buildroot 的
版本後綴,不是套件名。正確:`make lib_moxa_ies_auto_mibs-rebuild`。
順序(memory `feedback_build_order`):C lib → rust FFI → `plugin_moxa_snmp` →
`rust_moxa_build` → `app_moxa_framework` → `make`。
**首選作法:`/usr/local/bin/run_in_docker.sh "<command>" [project]`**
(不在 repo 裡,在 host 的 `/usr/local/bin/`,預設 project = `mds4xgl3`)。
它會自動確認容器存在、必要時 `docker start`,最後執行

```
docker exec mx_<project> bash -c "cd /home/moxa/<project>/buildroot && <command>"
```

—— **已經是 `bash -c`**,所以用它就不會踩到下面那個 PATH 坑。
例:`run_in_docker.sh "make"`、`run_in_docker.sh "make lib_moxa_ies_auto_mibs-rebuild"`。
使用者 2026-08-09 明示要用這支。

**最後的 `make` 會做 HSM 韌體簽章**(`hsm_tool/prepare_kernel_rootfs_to_sign.sh`,
預設 `HSM_SIGN_METHOD=ci` → 觸發 GitLab CI pipeline,官方金鑰 `SWITCH_Official_General`)。
**2026-08-09 使用者明示要我自己跑這步**(原本記載是「由使用者執行」,已不適用)。
用 `bash -c` 時它會自動跑完並產出 `.swu`,約數分鐘。

⚠️ 建置會**清空 `output/images/`**,舊 `.swu` 沒有備份(BKP/ 只有 EtherNet/IP zip)。

相關:[[feedback-build-order]]、[[project-dut-dual-image-ab-pair]]
