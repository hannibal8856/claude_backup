---
name: dut-hotswap-binary-without-firmware-update
description: DUT 可用 bind mount 熱抽換 binary/.so，不必燒 firmware；root 路徑是 ssh admin → su
metadata: 
  node_type: memory
  type: project
  originSessionId: 26ed1830-ec2a-4c7a-b95b-534394e470b4
  modified: 2026-08-05T16:20:45.223Z
---

DUT (192.168.127.253) 換一顆新 build 的 binary 不需要 firmware update。實測可行流程：

- `/` 是唯讀 squashfs（`/dev/root / squashfs ro`），檔案不能直接覆蓋；但 kernel 沒有開
  IMA / dm-verity / LoadPin，所以 exec 未簽章的 binary 不會被擋。
- 寫入空間：`/tmp` 是 overlay（rw，~490M free）。**`/overlayfs` 本身是 tmpfs**，所以
  `/etc` `/var` `/home` `/tmp` `/usr/share` `/mnt` `/opt` `/media` 這些 overlay 全是
  RAM-backed，重開機一律清空。真正持久可寫的只有 `/moxa`（`/dev/sda10` ext4，~1.9G free）
  和 `/env`（`/dev/sda9` vfat）。currently booted rootfs 是 `/dev/sda7`。
- 做法：scp 到 `/tmp` → `systemctl stop app_moxa_framework` →
  `mount --bind /tmp/新檔 /usr/bin/app_moxa_framework` → `systemctl start`。重開機自動還原。
- 工具：`~/.claude/skills/dut-console/dut_hotswap.sh`（吃 `output/target/...` 路徑，自動推
  導遠端路徑；`--restore` 還原）。14.5M binary scp 約 16 秒，整趟 < 40 秒。
- **`/usr/share` 本來就是 overlay mount**，是韌體自己的設計，還原時千萬別一起 umount。
- framework 相依多個 moxa `.so`（`libmoxa_snmp_agentx.so`、`libmoxa_fiber_check.so`、
  `libmoxa_encrypt.so` …），只換 binary 不夠時 `.so` 要一起 bind mount。
- 重啟 framework 只重啟 AgentX subagent，snmpd master 不動（sysUpTime 不會歸零），
  所以會發生一次 AgentX re-register。

**Why:** 每次改 framework 都重燒 65M 韌體太慢，這條路把驗證循環壓到一分鐘內。

**How to apply:** **預設一律用熱抽換，不要動不動就出 `.swu`**（使用者 2026-08-06 明講）。
build 完直接 `dut_hotswap.sh <output/target 下的檔案...>`，驗完 `--restore` 或重開機還原。

出 `.swu` 只在這幾種情況，其餘都先熱抽換：

- 改動範圍大到不只是幾個 `output/target` 下的檔案（例如 kernel、`.config`、
  post-build/post-image hook）
- 要驗的東西本身需要冷開機路徑，例如開機順序競賽（framework 一定比 snmpd 早起）
- 要驗的是「出貨的那顆 image」而不是「這支 binary」
- 使用者明確要求

出 `.swu` 前先 `test -s /tmp/.moxa_gitlab_scm_token`，缺了會整輪跑完才死在 HSM 簽章。
燒機用 `examinate-plan-e-swu` skill（會先報告要覆蓋哪個 partition，並用 md5 當硬門檻）。

相關：[[dut-ssh-expect-beats-serial-console]]、[[dut-root-login-via-su-not-ssh]]
