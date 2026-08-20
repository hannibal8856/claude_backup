# nos-console-autologin — 2026-08-20 工作備份

Buildroot serial-console 免密碼 autologin。三份互相關聯的產出:skill 本體、
把它收進 nos-cc-skill plugin 的設計 spec、以及實際套用在 NOS v7.0 樹上的 overlay。

## 內容

| 路徑 | 原始位置 | 說明 |
|---|---|---|
| `skill/` | `~/.claude/skills/buildroot-console-autologin/` | 個人 skill 本體(SKILL.md + probe.py)。**尚未**改名為 `nos-console-autologin`,仍是進 plugin 前的版本。 |
| `spec/` | `~/NOS_v7.0_develop/buildroot/claude_docs/` | 把 skill 收進 nos-cc-skill plugin 的設計 spec,已核可但 MR 暫緩。 |
| `buildroot-overlay/` | `~/NOS_v7.0_develop/buildroot/moxa/board/net/common/dev-autologin-overlay/` | 實際生效的 rootfs overlay。 |

## 尚未完成

MR 暫緩中。spec 裡的執行順序(issue #12 → branch → 三個 commit → 兩道 gate → MR)
一步都還沒做。nos-cc-skill repo 目前乾淨,停在 `main` @ `e065563`。

## 未收錄:autologin defconfig

`moxa/configs/mdsg4000l34xgs_autologin_defconfig` 沒有複製進來 —— 那是 Moxa 的
產品 defconfig,不適合整份放進個人 GitHub repo。它自己的檔頭寫明:

> Identical to mdsg4000l34xgs_defconfig except for the BR2_ROOTFS_OVERLAY

所以要重建它,只需要複製 `mdsg4000l34xgs_defconfig` 再加一行:

```
BR2_ROOTFS_OVERLAY="moxa/board/net/common/dev-autologin-overlay"
```

## 原理摘要

`ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,... %I $TERM` 一行做三件事:

- **免 login** —— agetty 不印提示、直接 exec `/bin/login -f root`;`-f` 表示「已認證」,
  PAM 的 auth stage 整段跳過,只剩 account/session。該樹的 account stage 是
  `account required pam_unix.so`,無 pam_nologin/securetty/access/faillock,沒有攔阻。
- **落在 zsh 而非 moxash** —— shell 由登入帳號的 `/etc/passwd` 第 7 欄決定。root 是
  build-time 使用者,shell 為 `/bin/zsh`;`admin` 是開機後由 `/usr/bin/device_import`
  建立並指向 `/usr/bin/moxashell.exe`。選 root 等於從未經過 admin。
- **root 權限** —— agetty 是 PID 1 子行程(uid 0),`login -f root` 目標即 root,
  不需降權,shell 直接繼承 uid 0。

三個一錯就壞的點:空的 `ExecStart=` 必須保留(ExecStart 會累加,否則兩個 agetty 搶 tty);
檔案放 `/usr/lib` 而非 `/lib`(該樹為 merged /usr,`check-merged-usr.sh` 會擋含裸 `lib/` 的 overlay);
drop-in 掛在 template `serial-getty@.service.d/` 而非 instance(getty instance 由
`systemd-getty-generator` 從 kernel `console=` 現生,`getty.target.wants` 本來就沒有 symlink)。

rootfs 是唯讀 squashfs,所以只能 build time 烘進去,runtime 改不了。

## 移除

```bash
grep -rl MOXA-DEV-AUTOLOGIN <buildroot>
```

刪掉 overlay 目錄與 autologin defconfig,重 build,確認 `output/target` 內 marker 也消失。
