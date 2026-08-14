---
name: build-is-users-job
description: 這個專案的開發一律在 container mx_SNMP_PLAN_E；build 前先確認撞到的是不是同一個 tree
metadata:
  node_type: memory
  type: feedback
  originSessionId: ba3523f8-fd26-456e-8fce-c6165f41d9f4
  modified: 2026-08-04T09:28:44.020Z
---

**這個專案的開發一律在 container `mx_SNMP_PLAN_E`**（使用者確認 2026-08-04），
tree 在 `/home/moxa/sdc1/home/moxa/SNMP_PLAN_E/buildroot`。

預設由使用者自己 build，但**他也會直接要求你 build**（2026-08-04 就是）。
被要求時就做，不要推回去——但下面的檢查一定要先跑。

**Why:** Plan E Task 4 時，subagent 在使用者同時也在 build 的情況下跑了
`make ...-rebuild`，撞到 `make -j` 的 libtool symlink race（`ln: File exists`）。
同一個 `output/` 目錄跑兩個 buildroot 會互相破壞，且事後無法確定 image 是否乾淨。
**危險的是共用同一個 output/ 樹，不是「機器上有 build 在跑」。**

**How to apply:**

- **build 前檢查衝突，而且要看清楚是哪個 tree**：

  ```
  pgrep -af "make|install.sh|expect" ; docker ps --format '{{.Names}}\t{{.Status}}'
  ls -l /proc/<pid>/cwd        # 決定性的一步：確認它跑在哪個 tree
  ```

  這台機器同時養著多個專案的容器（例如 `mx_TN-4500B_v2.0`）。
  **別的容器／別的 tree 在 build 不構成衝突**——2026-08-04 有一個 TN-4500B 的
  clippy scan 跑了近 4 小時，與 SNMP_PLAN_E 無關，照樣可以開工。
  只有 cwd 落在 `SNMP_PLAN_E/buildroot` 的才要停下來等。

- **只是要建置程式碼 → `run_in_docker.sh` 就夠了，不要加 `; make`**
  （使用者 2026-08-04：「Build code 其實跑 run_in_docker 就好」）：

  ```
  run_in_docker.sh "make <pkg1>-rebuild <pkg2>-rebuild rust_moxa_build-rebuild"
  ```

  多個 package 併在同一個 `make` 後面，不要拆成多行。
  `run_in_docker.sh` 預設就指向 `mx_SNMP_PLAN_E`，不必傳第二個參數。

- **只有要產出可燒錄的 image 時才加 `; make`**。那一步會重新打包整顆
  rootfs/boot 並走 HSM 簽章，產物是
  `output/images/FWR_MDS-G4000-L3-4XGS_v7.0_<date>.swu`（同時也會出 MIB/EtherNet-IP/
  PROFINET 的 zip）。不需要燒機時別做，白花時間。

- **`plugin_moxa_*`、`framework` 這類 package rebuild 之後，還要跑
  `make rust_moxa_build-rebuild` 才會生效** —— 列指令時別漏掉
- 交付變更時列出：改動的 buildroot package、對應 `dl/<repo>` 與 commit、受影響的目標執行檔
- **要主動告知曾執行過哪些 build 指令**（使用者明確要求）
- 容器外直接執行 make 會撞到 `snmp_script_rust/Makefile` 的 docker 偵測 bug
  （`&>/dev/null` 在 dash 下被誤解析），這是既有問題。
  cross toolchain（`/usr/local/gcc-linaro-.../arm-linux-gnueabihf-gcc`）**只存在於容器內**，
  所以主機上只能做 host gcc 的 `-fsyntax-only` 檢查，不能真的 cross-compile。

相關：[[report-changed-packages]]、[[snmp-work-notes-repo]]
