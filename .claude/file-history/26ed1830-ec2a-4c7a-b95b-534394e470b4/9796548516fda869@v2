#!/usr/bin/env bash
# Hot-swap freshly built binaries / shared libs onto the DUT without a
# firmware update.
#
# The DUT rootfs is read-only squashfs, so the files cannot be overwritten.
# Instead each new file is uploaded to /tmp (writable overlay) and bind-mounted
# over its original path. The swap lives until the next reboot.
#
# Usage:
#   dut_hotswap.sh [--host IP] output/target/usr/bin/app_moxa_framework ...
#   dut_hotswap.sh --restore [--host IP]
#
# Paths must be under $BR/output/target; the remote path is derived by
# stripping that prefix.

set -euo pipefail

BR="${BR:-/home/moxa/sdc1/home/moxa/SNMP_PLAN_E/buildroot}"
HOST="192.168.127.253"
USER="admin"
PASS="moxa"
SERVICE="app_moxa_framework.service"
RESTORE=0

FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --host)    HOST="$2"; shift 2 ;;
        --service) SERVICE="$2"; shift 2 ;;
        --restore) RESTORE=1; shift ;;
        *)         FILES+=("$1"); shift ;;
    esac
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# expect helper: scp a file, then run a script as root over ssh.
cat > "$WORK/drive.exp" <<'EXP'
set timeout 300
log_user 1
set host   [lindex $argv 0]
set user   [lindex $argv 1]
set pass   [lindex $argv 2]
set script [lindex $argv 3]
set files  [lrange $argv 4 end]

set sshopt "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no"

foreach pair $files {
    set local  [lindex [split $pair "|"] 0]
    set remote [lindex [split $pair "|"] 1]
    spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              -o PubkeyAuthentication=no $local $user@$host:$remote
    expect -re {[Pp]assword:} { send "$pass\r" }
    expect eof
}

spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $script $user@$host:/tmp/_hotswap.sh
expect -re {[Pp]assword:} { send "$pass\r" }
expect eof

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $user@$host
expect -re {[Pp]assword:} { send "$pass\r" }
expect -re {\$ $}
# root's login shell is zsh and its prompt is not a plain "# ", so sync on
# an explicit marker instead of the prompt.
send "su\r"
expect -re {[Pp]assword:} { send "$pass\r" }
sleep 3
send "sh /tmp/_hotswap.sh 2>&1\r"
expect {
    -re {HOTSWAP_DONE} {}
    timeout { puts "\n>>> TIMEOUT waiting for HOTSWAP_DONE" }
}
sleep 2
send "exit\r"
sleep 1
send "exit\r"
expect eof
EXP

if [ "$RESTORE" = "1" ]; then
    cat > "$WORK/remote.sh" <<EOF
#!/bin/sh
# Only undo paths this tool recorded — the firmware has overlay mounts of
# its own (e.g. /usr/share) that must be left alone.
systemctl stop $SERVICE
if [ -f /tmp/hotswap_list ]; then
    while read -r m; do
        umount "\$m" 2>/dev/null && echo "restored \$m"
    done < /tmp/hotswap_list
    rm -f /tmp/hotswap_list
else
    echo "nothing recorded in /tmp/hotswap_list"
fi
systemctl start $SERVICE
sleep 5
systemctl is-active $SERVICE
echo HOTSWAP_DONE
EOF
    expect "$WORK/drive.exp" "$HOST" "$USER" "$PASS" "$WORK/remote.sh"
    exit 0
fi

[ ${#FILES[@]} -gt 0 ] || { echo "no files given" >&2; exit 1; }

# Build the upload list and the remote swap script together.
UPLOADS=()
{
    echo "#!/bin/sh"
    echo "set -e"
    echo "systemctl stop $SERVICE"
    echo "sleep 2"
} > "$WORK/remote.sh"

for f in "${FILES[@]}"; do
    abs="$(readlink -f "$f")"
    case "$abs" in
        "$BR/output/target/"*) ;;
        *) echo "not under \$BR/output/target: $f" >&2; exit 1 ;;
    esac
    remote_path="${abs#$BR/output/target}"
    base="$(basename "$abs")"
    staged="/tmp/hotswap_$base"
    UPLOADS+=("$abs|$staged")
    {
        echo "chown root:root $staged; chmod 755 $staged"
        # Drop a previous swap first so we always stack on the pristine file.
        echo "umount $remote_path 2>/dev/null || true"
        echo "mount --bind $staged $remote_path"
        echo "grep -qxF '$remote_path' /tmp/hotswap_list 2>/dev/null || echo '$remote_path' >> /tmp/hotswap_list"
        echo "echo 'swapped: $remote_path'"
        echo "md5sum $remote_path"
    } >> "$WORK/remote.sh"
    echo "  $abs  ->  $remote_path"
done

{
    echo "systemctl start $SERVICE"
    echo "sleep 5"
    echo "systemctl is-active $SERVICE || true"
    echo "systemctl show $SERVICE -p MainPID -p SubState --no-pager"
    echo "echo HOTSWAP_DONE"
} >> "$WORK/remote.sh"

expect "$WORK/drive.exp" "$HOST" "$USER" "$PASS" "$WORK/remote.sh" "${UPLOADS[@]}"
