#!/usr/bin/env bash
# Examine / upload / flash a Plan E .swu firmware image on the DUT.
#
# Three stages, each additive. The default stage is read-only.
#
#   swu_examine.sh <file.swu>              # stage 1: examine only, changes nothing
#   swu_examine.sh --upload <file.swu>     # stage 1 + scp to DUT /tmp + md5 compare
#   swu_examine.sh --flash  <file.swu>     # stage 1 + 2 + swupdate -i, sync, reboot
#
# Options:
#   --host IP        DUT address (default 192.168.127.253)
#   --protect N      partition that must never be overwritten (default 2,
#                    the mainline control group). "--protect none" disables.
#   --control-build  BUILD_TIME the control group must have (default
#                    2026_0805_2335). Flashing is only correct when booted ON
#                    the control group, so at stage 3 the RUNNING BUILD_TIME
#                    must equal this. "--control-build none" disables.
#   --keep           do not delete the staged /tmp/<file>.swu after flashing
#
# Why the stages: a truncated .swu written to a partition bricks that
# partition, so the md5 comparison in stage 2 is a hard gate on stage 3.

set -euo pipefail

HOST="192.168.127.253"
USER="admin"
PASS="moxa"
PROTECT="2"      # partition 2 holds the mainline control group image
CONTROL_BUILD="2026_0805_2335"   # the NOS 7 mainline control group's BUILD_TIME
STAGE=1          # 1=examine 2=upload 3=flash
KEEP=0
SWU=""

while [ $# -gt 0 ]; do
    case "$1" in
        --host)    HOST="$2"; shift 2 ;;
        --protect) PROTECT="$2"; shift 2 ;;
        --control-build) CONTROL_BUILD="$2"; shift 2 ;;
        --upload)  STAGE=2; shift ;;
        --flash)   STAGE=3; shift ;;
        --keep)    KEEP=1; shift ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        -*)        echo "unknown option: $1" >&2; exit 1 ;;
        *)         SWU="$1"; shift ;;
    esac
done

[ -n "$SWU" ] || { echo "usage: $0 [--upload|--flash] <file.swu>" >&2; exit 1; }
[ -f "$SWU" ] || { echo "no such file: $SWU" >&2; exit 1; }

SWU="$(readlink -f "$SWU")"
BASE="$(basename "$SWU")"
SIZE=$(stat -c %s "$SWU")

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- stage 1a
# Local inspection. A .swu is a plain cpio archive; sw-description names the
# product, and preinstall.sh is what decides which partition gets written.
echo "=== local ==="
echo "file : $SWU"
echo "size : $SIZE bytes ($((SIZE / 1024 / 1024)) MiB)"

( cd "$WORK" && cpio -idu --quiet < "$SWU" ) || {
    echo "not a readable cpio archive — is this really a .swu?" >&2; exit 1; }

[ -f "$WORK/sw-description" ] || { echo "no sw-description in archive" >&2; exit 1; }

PRODUCT=$(sed -n 's/^\s*\([A-Za-z0-9_]\+\)\s*=\s*{.*/\1/p' "$WORK/sw-description" | head -1)
echo "product   : ${PRODUCT:-<unparsed>}"
echo "payloads  : $(ls "$WORK" | grep -v '^sw-description$' | tr '\n' ' ')"

LOCAL_MD5=$(md5sum "$SWU" | cut -d' ' -f1)
echo "md5       : $LOCAL_MD5"

# ---------------------------------------------------------------- stage 1b
# DUT state. Everything needed to say which partition is about to die.
echo
echo "=== DUT $HOST ==="

# The landing shell is itself the partition discriminator: the Plan E image
# drops straight into a Linux shell, the mainline image lands in moxash.
cat > "$WORK/probe.exp" <<'EXP'
set timeout 60
log_user 0
set host [lindex $argv 0]
set user [lindex $argv 1]
set pass [lindex $argv 2]
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $user@$host
expect -re {[Pp]assword:} { send "$pass\r" }
expect {
    -re {moxa[#>] ?$} { puts "\nSHELL=moxash"; exit 7 }
    -re {\$ $}        { }
    timeout           { puts "\nSHELL=unknown"; exit 3 }
}
send "su\r"
expect -re {[Pp]assword:} { send "$pass\r" }
sleep 3
log_user 1
send "echo PROBE_BEGIN; cat /etc/moxa/version/BUILD_TIME; echo; fw_printenv fwrbootpart; sed 's/ /\\n/g' /proc/cmdline | grep '^root='; df -k /tmp | tail -1; echo PROBE_END\r"
expect { -re {PROBE_END} {} timeout { puts "\n>>> TIMEOUT probing DUT" } }
log_user 0
send "exit\r"; sleep 1; send "exit\r"
expect eof
EXP

PROBE_RC=0
expect "$WORK/probe.exp" "$HOST" "$USER" "$PASS" \
    | tr -d '\r' > "$WORK/probe.out" || PROBE_RC=$?

if grep -q 'SHELL=moxash' "$WORK/probe.out"; then
    echo "landed in moxash — this is the mainline image, not Plan E."
    echo "This script drives a Linux shell only; it cannot yet get from moxash"
    echo "to a Linux root shell unattended. Do the flash by hand from there."
    exit 7
fi

# The echoed command line also contains the markers, so take the LAST block.
sed -n '/PROBE_BEGIN/,/PROBE_END/p' "$WORK/probe.out" | tail -n +2 > "$WORK/probe.clean"

BUILD_TIME=$(grep -m1 -E '^[0-9]{4}_[0-9]{4}_[0-9]{4}' "$WORK/probe.clean" || echo "?")
BOOTPART=$(sed -n 's/^fwrbootpart=\([12]\).*/\1/p' "$WORK/probe.clean" | head -1)
ROOTDEV=$(sed -n 's/^root=\(\S*\).*/\1/p' "$WORK/probe.clean" | head -1)
TMPFREE=$(awk '/\/tmp$/ {print $4}' "$WORK/probe.clean" | head -1)

if [ -z "$BOOTPART" ]; then
    echo "could not read fwrbootpart from the DUT — is it up and on a Linux shell?" >&2
    sed 's/^/  | /' "$WORK/probe.clean" >&2
    exit 1
fi

echo "running   : $BUILD_TIME   (fwrbootpart=$BOOTPART, root=$ROOTDEV)"

# Mirrors preinstall.sh: booted on 1 -> writes sda3+sda8, booted on 2 -> sda2+sda7.
if [ "$BOOTPART" = "1" ]; then
    VICTIM=2; NEWKERN="${ROOTDEV%?}3"; NEWROOT="${ROOTDEV%?}8"
else
    VICTIM=1; NEWKERN="${ROOTDEV%?}2"; NEWROOT="${ROOTDEV%?}7"
fi

echo "will WRITE: partition $VICTIM  ($NEWKERN kernel, $NEWROOT rootfs)"
echo "will KEEP : partition $BOOTPART ($BUILD_TIME)"
echo "/tmp free : $((TMPFREE / 1024)) MiB  (need $((SIZE / 1024 / 1024)) MiB)"

# ---------------------------------------------------------------- stage 1c
# The control-group guard. swupdate always writes the partition you are NOT
# running, so booting the image you want to keep is what destroys it.
if [ "$VICTIM" = "$PROTECT" ]; then
    echo
    echo "!! REFUSING: partition $VICTIM is the protected mainline control group."
    echo "!! swupdate writes the partition you are NOT running, so flashing from"
    echo "!! here would overwrite it."
    echo "!!"
    echo "!! To put this build on partition $BOOTPART instead, switch first:"
    echo "!!     printf 'Y\\nY\\n' | /moxa/fwr_change.sh     # on the DUT, as root"
    echo "!! wait for the reboot, then run this script again from there."
    echo "!!"
    echo "!! If you really do mean to overwrite partition $VICTIM, pass --protect none."
    exit 2
fi

# ---------------------------------------------------------------- stage 1d
# Control-group IDENTITY check. The guard above only knows partition NUMBERS.
# If someone ever flashed with --protect none, partition $PROTECT may no longer
# hold the control group, and the number-based guard would happily "protect"
# the wrong image. Flashing is only correct when booted ON the control group
# (swupdate then writes the other side), so the RUNNING BUILD_TIME is the
# control group's and can be asserted directly.
if [ "$CONTROL_BUILD" != "none" ]; then
    if [ "$BUILD_TIME" = "$CONTROL_BUILD" ]; then
        echo "control   : running the expected control group ($CONTROL_BUILD)"
    else
        echo "control   : running $BUILD_TIME, expected control group $CONTROL_BUILD"
        if [ "$STAGE" -ge 3 ]; then
            echo
            echo "!! REFUSING: flashing must be done FROM the control group, so the"
            echo "!! running image should be $CONTROL_BUILD but is $BUILD_TIME."
            echo "!! Either you are booted on the wrong side, or partition $PROTECT no"
            echo "!! longer holds the control group (someone used --protect none)."
            echo "!!"
            echo "!! Check the other side before doing anything destructive."
            echo "!! If the control group has legitimately moved on, pass"
            echo "!!     --control-build <new BUILD_TIME>   (or --control-build none)"
            exit 3
        fi
    fi
fi

if [ "$TMPFREE" -lt $((SIZE / 1024 + 8192)) ]; then
    echo "!! not enough room in /tmp" >&2
    [ "$STAGE" -ge 2 ] && exit 1
fi

[ "$STAGE" -ge 2 ] || { echo; echo "examine only — nothing was changed."; exit 0; }

# ------------------------------------------------------------------ stage 2
# Upload and verify. This replaces /moxa/upload_my_file.sh, which pulls from
# this very host and only *prints* the md5 without comparing it.
echo
echo "=== upload ==="

cat > "$WORK/push.exp" <<'EXP'
set timeout 600
log_user 1
set host  [lindex $argv 0]
set user  [lindex $argv 1]
set pass  [lindex $argv 2]
set local [lindex $argv 3]
set base  [lindex $argv 4]
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $local $user@$host:/tmp/$base
expect -re {[Pp]assword:} { send "$pass\r" }
expect eof
EXP

expect "$WORK/push.exp" "$HOST" "$USER" "$PASS" "$SWU" "$BASE"

cat > "$WORK/md5.exp" <<'EXP'
set timeout 300
log_user 0
set host [lindex $argv 0]
set user [lindex $argv 1]
set pass [lindex $argv 2]
set base [lindex $argv 3]
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $user@$host
expect -re {[Pp]assword:} { send "$pass\r" }
expect -re {\$ $}
log_user 1
send "echo MD5_BEGIN; md5sum /tmp/$base; echo MD5_END\r"
expect { -re {MD5_END} {} timeout { puts "\n>>> TIMEOUT on md5sum" } }
log_user 0
send "exit\r"
expect eof
EXP

REMOTE_MD5=$(expect "$WORK/md5.exp" "$HOST" "$USER" "$PASS" "$BASE" | tr -d '\r' \
    | sed -n '/MD5_BEGIN/,/MD5_END/p' | grep -oE '^[0-9a-f]{32}' | head -1 || true)

echo "local  md5: $LOCAL_MD5"
echo "remote md5: ${REMOTE_MD5:-<none>}"

if [ "$REMOTE_MD5" != "$LOCAL_MD5" ]; then
    echo "!! md5 MISMATCH — the upload is corrupt or truncated. NOT flashing." >&2
    exit 1
fi
echo "md5 match."

[ "$STAGE" -ge 3 ] || { echo; echo "uploaded to /tmp/$BASE — not flashed."; exit 0; }

# ------------------------------------------------------------------ stage 3
# Flash. swupdate's own postinstall.sh does a sha256 readback of both written
# partitions and only then flips fwrbootpart, so a bad write leaves the boot
# pointer where it is.
echo
echo "=== flash (partition $VICTIM) ==="

RM_LINE="rm -f /tmp/$BASE"
[ "$KEEP" = "1" ] && RM_LINE="true"

cat > "$WORK/flash.exp" <<EXP
set timeout 900
log_user 1
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \\
          -o PubkeyAuthentication=no $USER@$HOST
expect -re {[Pp]assword:} { send "$PASS\r" }
expect -re {\\\$ \$}
send "su\r"
expect -re {[Pp]assword:} { send "$PASS\r" }
sleep 3
send "swupdate -i /tmp/$BASE; echo SWUPDATE_RC=\\\$?\r"
expect {
    -re {SWUPDATE_RC=0}  { puts "\n>>> swupdate OK" }
    -re {SWUPDATE_RC=[1-9]} { puts "\n>>> swupdate FAILED — not rebooting"; exit 1 }
    timeout { puts "\n>>> TIMEOUT during swupdate"; exit 1 }
}
send "$RM_LINE; fw_printenv fwrbootpart; sync\r"
sleep 5
send "reboot\r"
sleep 3
expect eof
EXP

expect "$WORK/flash.exp"

echo
echo "rebooting. the DUT should come back on partition $VICTIM with the new build."
echo "confirm with:  bash ~/.claude/skills/dut-console/run.sh 'cat /etc/moxa/version/BUILD_TIME'"
