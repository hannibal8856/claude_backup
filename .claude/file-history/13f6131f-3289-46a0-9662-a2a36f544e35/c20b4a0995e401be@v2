---
name: examinate-plan-e-swu
description: Examine, upload and flash a Plan E .swu firmware image on the Moxa MDS-G4000-L3-4XGS DUT. Reports which dual-image partition the update will overwrite before touching anything, refuses to overwrite the mainline control group, scp's the .swu to /tmp, hard-gates on an md5 comparison, then runs swupdate + sync + reboot. Use when the user wants to check a .swu, put a new Plan E build on the device, verify a full image (not a hot-swapped binary), or asks which partition is about to be overwritten.
---

# Examinate Plan E SWU

Full-image firmware verification for the DUT at `192.168.127.253`.

Reach for this only when a hot-swap is not enough — a big change, something
that needs a cold boot, or verifying the shipping image. For one freshly built
binary or `.so`, `~/.claude/skills/dut-console/dut_hotswap.sh` is the default:
under a minute, no reboot, no partition risk.

## Partition policy — read this first

The device is dual-image, and `swupdate` **always writes the partition you are
NOT running**, then flips the boot pointer to it. From `preinstall.sh` inside
the .swu:

| booted on | `root=` | writes kernel | writes rootfs | then `fwrbootpart` → |
|---|---|---|---|---|
| partition 1 | `/dev/sda7` | `/dev/sda3` | `/dev/sda8` | 2 |
| partition 2 | `/dev/sda8` | `/dev/sda2` | `/dev/sda7` | 1 |

The consequence people get backwards: **booting the image you want to keep is
what destroys it.**

On this bench:

| partition | image | `BUILD_TIME` | role |
|---|---|---|---|
| 1 | Plan E | `2026_0730_1302` | development — **this is the one to overwrite** |
| 2 | NOS 7 mainline | `2026_0805_2335` | control group — **must survive** |

The control group is the reference for every before/after comparison (it is
what separated "Plan E broke this" from "this was already broken" when the
`stdethdb/` delegation was measured, ADR-0011). Losing it costs a reflash and
invalidates any comparison made in the meantime.

So a new Plan E build must be flashed **from partition 2**, not from Plan E
itself: boot the control group, then flash — the write lands on partition 1
and `fwrbootpart` flips back to 1.

Two independent gates enforce this, because they fail differently:

1. **`--protect 2`** (default) — refuses any destructive stage whose victim is
   partition 2. Catches "flashing from the wrong side".
2. **`--control-build 2026_0805_2335`** (default) — at stage 3, asserts the
   *running* `BUILD_TIME` really is the control group's. Catches "partition 2
   is no longer the control group", which the number-based gate cannot see —
   e.g. after someone used `--protect none` once.

Override with `--protect none` / `--control-build none` only if the control
group is genuinely expendable, or with `--control-build <new BUILD_TIME>` if
the control group has legitimately been updated.

## Usage

```bash
S=~/.claude/skills/examinate-plan-e-swu/swu_examine.sh

# Stage 1 — examine only. Changes nothing. Safe to run any time.
bash $S /tftpboot/FWR_MDS-G4000-L3-4XGS_v7.0_....swu

# Stage 2 — also scp to the DUT /tmp and compare md5 (local vs remote).
bash $S --upload /tftpboot/FWR_....swu

# Stage 3 — also swupdate -i, sync, reboot.
bash $S --flash /tftpboot/FWR_....swu
```

Options: `--host IP` (default `192.168.127.253`), `--protect N|none`
(default `2`), `--keep` (leave `/tmp/<name>.swu` on the device afterwards).

**Always run stage 1 and show the user its output before flashing.** It is the
only step that names the image about to be destroyed, and that is the one
irreversible thing here.

## Full procedure for flashing a new Plan E build

1. Stage 1 from wherever the DUT currently is — read `running`, `will WRITE`
   and the `control` line.
2. If it refuses (currently booted on Plan E `2026_0730_1302`, victim = the
   control group), switch partitions on the DUT as root:
   `printf 'Y\nY\n' | /moxa/fwr_change.sh` — the two `Y`s answer its two
   interactive prompts, they are not arguments. Wait ~40 s for the reboot.
3. Re-run stage 1. It must now say `will WRITE: partition 1` **and**
   `control: running the expected control group (2026_0805_2335)`. If the
   control line disagrees, stop and find out what is on the other side before
   flashing anything.
4. From the mainline side, `--flash` the new .swu. It lands on partition 1 and
   `fwrbootpart` flips back to 1.
5. Reboot puts the new Plan E build up. Confirm `BUILD_TIME` changed — it
   should no longer be `2026_0730_1302`.

Every stage works from either side. The mainline image on partition 2 was
rebuilt from `2026_0805_2335.swu` and now lands ssh logins in a Linux `/bin/sh`
too, so the script drives it the same way it drives Plan E.

The `moxash` detection in the probe stays as a safety net — an older mainline
image would land there, and the script exits 7 with an explanation instead of
hanging the way a bare `expect` on a `$` prompt would.

## Why the md5 gate exists

`/tmp` on the DUT is a RAM-backed overlay (~505 MiB free). A truncated `.swu`
written to a partition bricks that partition. The script fails hard on an md5
mismatch and refuses to flash.

The device's own `/moxa/upload_my_file.sh` does the same transfer in the other
direction — it `scp`s *from* `moxa@192.168.127.209:/tftpboot/`, which is this
development host. That path needs the host account's password and only *prints*
the md5 without comparing it. This skill pushes instead, using the DUT's
`admin`/`moxa`, and compares automatically. **Do not ask the user for their
workstation password.**

`postinstall.sh` inside the .swu sha256-verifies both written partitions before
flipping `fwrbootpart`, so a bad write leaves the device booting the old image.

Note `/moxa/fwr_update.sh` does **not** exist. The only two scripts under
`/moxa/` are `fwr_change.sh` (partition switch) and `upload_my_file.sh`.

## After flashing

The reboot drops the ssh session; that is expected. Boot takes roughly 40 s.

```bash
bash ~/.claude/skills/dut-console/run.sh "cat /etc/moxa/version/BUILD_TIME" "fw_printenv fwrbootpart"
```

Always confirm `BUILD_TIME` actually changed before starting any measurement —
a silently failed update leaves the old build running and every number
collected afterwards comes from the wrong image.

## Prerequisites

`expect` on the host and ssh reachability to the DUT. Credentials are
`admin`/`moxa`, with `su` (same password) for root; root ssh is blocked by
`PermitRootLogin prohibit-password`. The DUT's sshd stops granting new sessions
after a number of connections — if probes start timing out, reboot the DUT.
