---
name: dut-root-login-via-su-not-ssh
description: "DUT root 只能 ssh admin/moxa 再 su moxa；root shell 是 zsh，prompt 不是 \"# \"，expect 要用 marker 同步"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 26ed1830-ec2a-4c7a-b95b-534394e470b4
  modified: 2026-08-05T09:04:02.646Z
---

DUT SSH 拿 root 的唯一路徑：`ssh admin@192.168.127.253`（密碼 moxa）→ `su`（密碼 moxa）。

- `ssh root@` 會被拒：sshd 是預設的 `PermitRootLogin prohibit-password`，只收金鑰，
  而 `/root` 在唯讀 squashfs 上，塞不了 authorized_keys。
- admin 登進去是 `uid=1002(admin_internal)`、shell 為 dash、prompt `$ `。
- **su 之後 root 的 login shell 是 zsh，prompt 仍印成 `$ ` 並前綴一串反白控制碼**，
  用 `expect -re {# $}` 一定判成 su 失敗。要改用自己 echo 的 marker 字串同步。
- `systemctl show/status` 會走 pager 噴 `[0;0H` 之類的洗版控制碼，記得加 `--no-pager`。
- expect script 內 `$(...)` 會被 Tcl 當變數展開，遠端指令請寫成 .sh 檔 scp 過去再跑。

**Why:** 這幾個坑每次重寫 expect 都會再踩一次，浪費好幾輪 SSH session。

**How to apply:** 需要在 DUT 跑 root 指令時，用「寫 .sh → scp → su → sh /tmp/x.sh →
等 marker」這個樣板，參考 [[dut-hotswap-binary-without-firmware-update]] 裡的
`dut_hotswap.sh`。相關：[[dut-ssh-expect-beats-serial-console]]
