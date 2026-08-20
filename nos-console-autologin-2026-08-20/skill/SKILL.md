---
name: buildroot-console-autologin
description: >-
  Bake passwordless serial-console autologin into a Buildroot image (dev builds
  only). Probes any Buildroot tree for init system, getty wiring, PAM, and
  read-only rootfs, then emits an overlay drop-in (systemd) or inittab line
  (busybox/sysv) plus the defconfig change. Use when asked to make a built
  image log in without a password, add console autologin, get a root shell on
  ttyS0 without credentials, or evaluate whether that is possible in a given
  buildroot tree.
---

# Buildroot serial-console autologin

Makes the **serial console** drop straight into a root shell with no username
or password. Development images only.

## Safety gate — do this first, every time

This removes authentication from the console entirely: physical (or
console-server) access becomes root access, with no log of who.

1. **Say so in one sentence and get an explicit go-ahead** before writing files.
2. **Refuse silently-shipping paths.** If the config being edited is the one CI
   or release builds use, say so and offer a separate dev defconfig instead.
   Never put an unguarded autologin into a post-build script that other
   products share (the probe prints how many configs share it).
3. **Make it greppable.** Every file this skill writes carries the marker
   `MOXA-DEV-AUTOLOGIN` in a comment so it can be found and removed later.
4. **SSH is out of scope.** This touches the console only. Passwordless SSH is
   a different, higher-risk change — if asked, treat it as a separate request.

## Step 1 — probe (works from any path)

```bash
python3 ~/.claude/skills/buildroot-console-autologin/scripts/probe.py [path]
```

`path` may be the Buildroot root or anything inside it; with no argument it
walks up from CWD looking for a directory with both `package/` and `Makefile`.
It reads the **configured** `.config` (not a guessed defconfig) and inspects
`output/target/`, then prints a verdict.

**Do not skip the probe and reuse numbers from a previous tree.** Getty port,
init system and product differ per tree — one product family here uses
`ttyPS0`, another `ttyS1`.

If `output/target/` is absent, the config half still works; say which checks
are pending a build rather than assuming they pass.

> Local trap: this machine's shell hook rewrites `find`/`ls`/`grep` output and
> has invented entries. **Existence claims must come from `python3`**, which is
> what the probe uses. Do not "confirm" a probe result with `ls`.

## Step 2 — choose the delivery mechanism

Prefer in this order:

1. **`BR2_ROOTFS_OVERLAY`** — one new file plus one defconfig line, removable
   by deleting the line. Does not touch anything shared.
2. **Flag-guarded block in the post-build script** — only if the tree already
   has a per-product post-build script, and only wrapped in a new
   `BR2_MOXA_DEV_AUTOLOGIN`-style flag following that script's existing
   `if [ "${BR2_...}" == "y" ]` convention.
3. Never: an unguarded edit to a post-build script shared across products.

A read-only rootfs (`BR2_TARGET_ROOTFS_SQUASHFS=y`, `/etc/fstab` showing `ro`)
means runtime edits are impossible — build time is the only option. That is a
reason to use this skill, not a blocker.

## Step 3a — systemd trees

Write into the overlay, mirroring the target layout:

```
<overlay>/lib/systemd/system/serial-getty@.service.d/99-autologin.conf
```

```ini
# MOXA-DEV-AUTOLOGIN - development images only, remove before release
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --keep-baud <BAUD>,115200,57600,38400,9600 %I $TERM
```

Three things that break this if you get them wrong:

- **The empty `ExecStart=` is mandatory.** `ExecStart` accumulates; without the
  reset you get two agetty processes fighting for the tty.
- **Use `/lib/systemd/system/...`, not `/etc/systemd/system/...`.** Some
  products regenerate or overlay `/etc` at runtime; `/lib` is untouched.
- **Drop-ins apply to every instance of the template**, including ones created
  at boot by `systemd-getty-generator` from the kernel `console=` argument. So
  it works even when there is no `getty.target.wants/` symlink — which is the
  normal case on these boards. Do not try to "fix" the missing symlink.

`--autologin root` makes agetty exec `login -f root`. **`-f` skips PAM's `auth`
stage**, so only `account` and `session` matter — check the probe's
"PAM blockers" line, not the auth line.

If the tree has `debug-shell.service`, mention it: `systemctl enable
debug-shell.service` gives a root shell on tty9 with no image change at all.
It is a weaker tool (not the main console) but sometimes it is all that is
needed.

## Step 3b — busybox-init / sysv trees

No drop-in mechanism. Add to `/etc/inittab` via the overlay:

```
# MOXA-DEV-AUTOLOGIN
<TTY>::respawn:/sbin/getty -n -l /bin/sh -L <TTY> <BAUD> vt100
```

`-n` suppresses the login prompt, `-l /bin/sh` replaces `/bin/login`. Confirm
`/sbin/getty` is busybox's (the probe reports it); util-linux agetty uses
`--autologin` instead and does not accept `-n -l` the same way.

## Step 4 — pick the user

**root, unless proven otherwise.** Autologin as a user that does not exist when
getty starts makes `login -f` fail and the unit respawn-loop.

The probe prints `build-time users`. Anything not on that list — on these Moxa
trees `admin` is the usual example — is created at runtime by the framework and
is **not** safe to target. Autologin as root also lands in root's configured
shell (often `/bin/zsh` here, set by the post-build script), bypassing any
vendor CLI shell such as `moxash`, which is normally what the user wants.

## Step 5 — verify

After the build, before flashing:

```bash
# the file made it into the image tree
python3 - <<'EOF'
import os
t = "<buildroot>/output/target/lib/systemd/system/serial-getty@.service.d/99-autologin.conf"
print(os.path.exists(t) and open(t).read())
EOF
```

On the device: the console shows no `login:` prompt and lands on a shell prompt
as root. If it loops, the two usual causes are a missing empty `ExecStart=`
(two agettys) or an autologin user that does not exist yet.

Image signing is unaffected: post-build and overlay both run **before** image
assembly, so the change is inside whatever gets signed.

## Removal

```bash
grep -rl MOXA-DEV-AUTOLOGIN <buildroot>
```

Delete the file (and the `BR2_ROOTFS_OVERLAY` line if it was added only for
this), then rebuild. Confirm the marker is gone from `output/target` too.

## Report back

State plainly which of these were **verified in this tree** and which are
assumed: init system, getty port, agetty/login present, PAM stack, read-only
rootfs, delivery mechanism chosen, and whether a build/boot test has actually
been run. A static assessment is not a working autologin — say which one you
are handing over.
