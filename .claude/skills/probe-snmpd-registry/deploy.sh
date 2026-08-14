#!/bin/bash
#
# deploy.sh -- build, install and read the snmpd registry probe on the Moxa DUT.
#
# The two steps this script exists to make unskippable:
#   * restarting snmpd through moxash (the [y/N] prompt leaves SNMP DISABLED if
#     nobody answers it, because "acc dis" has already run by then)
#   * triggering TWICE and refusing to report unless the counts agree -- the
#     registry is not stable until every subagent has re-registered, and a
#     half-populated registry is indistinguishable from "that subagent does not
#     register this OID". Measured: 2002/1850 shortly after restart vs
#     3755/3014 settled, same probe, same device.
#
# Usage:
#   deploy.sh            build + deploy + restart snmpd + read
#   deploy.sh --read     read only (probe already loaded)
#   deploy.sh --clean    remove the dlmod conf from the DUT
set -o pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT=mds4xgl3
BUILDROOT=~/mds4xgl3/buildroot
TOOLS=~/mds4xgl3/tools
RUNNER=/usr/local/bin/run_in_docker.sh
RESTART=~/moxash_snmp_restart.exp
DUT=192.168.127.253
COMMUNITY=public
TRIGGER_OID=.1.3.6.1.4.1.8691.9999.1.0
REMOTE_SO=/tmp/chainprobe.so
REMOTE_CONF=/etc/moxa/netsnmp/config/zz_chainprobe.conf
REMOTE_OUT=/tmp/chain.txt
OUTDIR=~/pcap

MODE=full
case "$1" in
    --read)  MODE=read ;;
    --clean) MODE=clean ;;
    "")      ;;
    *)       echo "unknown option: $1" >&2; exit 2 ;;
esac

if [ "$MODE" = clean ]; then
    expect "$TOOLS/dutroot.exp" "rm -f $REMOTE_CONF $REMOTE_SO; ls $REMOTE_CONF" \
        >/dev/null 2>&1
    echo "removed $REMOTE_CONF and $REMOTE_SO"
    echo "note: snmpd keeps the probe loaded until its next restart."
    exit 0
fi

# --- trigger the probe and print the summary line ---------------------------
# Returns the summary via stdout; the caller compares two of them.
read_summary() {
    local dst="$1"
    /usr/bin/snmpget -v2c -c "$COMMUNITY" -t 10 -r 1 -On "$DUT" "$TRIGGER_OID" \
        >/dev/null 2>&1 || { echo "TRIGGER_FAILED"; return 1; }
    expect "$TOOLS/dutget.exp" "$REMOTE_OUT" "$dst" >/dev/null 2>&1 \
        || { echo "FETCH_FAILED"; return 1; }
    grep -E '^total_subtrees=' "$dst"
}

if [ "$MODE" = full ]; then
    echo "building chainprobe.so ..."
    cp "$SKILL_DIR/chainprobe.c" "$BUILDROOT/output/build/chainprobe.c" || exit 1
    (cd ~/mds4xgl3 && "$RUNNER" "cd output/build && \
        ../host/bin/arm-linux-gnueabihf-gcc -shared -fPIC -o chainprobe.so \
        chainprobe.c -I../staging/usr/include -L../staging/usr/lib \
        -lnetsnmpagent -lnetsnmp -ldl -Wall" "$PROJECT") || {
        echo "build FAILED" >&2; exit 1; }

    echo "deploying ..."
    expect "$TOOLS/dutscp.exp" "$BUILDROOT/output/build/chainprobe.so" "$REMOTE_SO" \
        >/dev/null 2>&1 || { echo "scp FAILED" >&2; exit 1; }
    expect "$TOOLS/dutroot.exp" \
        "printf 'dlmod chainprobe $REMOTE_SO\n' > $REMOTE_CONF" >/dev/null 2>&1

    echo "restarting snmpd through moxash ..."
    expect "$RESTART" >/dev/null 2>&1 || {
        echo "restart FAILED -- SNMP MAY BE LEFT DISABLED, check the DUT" >&2
        exit 1; }
fi

mkdir -p "$OUTDIR"
STAMP=$(date +%Y-%m-%d_%H%M%S)
A="$OUTDIR/chain_${STAMP}_1.txt"
B="$OUTDIR/chain_${STAMP}_2.txt"

echo "trigger 1 ..."
S1=$(read_summary "$A") || { echo "$S1" >&2; exit 1; }
echo "  $S1"
echo "trigger 2 (settle check) ..."
S2=$(read_summary "$B") || { echo "$S2" >&2; exit 1; }
echo "  $S2"

if [ "$S1" != "$S2" ]; then
    echo
    echo "REGISTRY NOT SETTLED -- the two reads disagree." >&2
    echo "Subagents are still re-registering. Wait and run --read again;" >&2
    echo "do NOT draw any 'X is not registered' conclusion from these files." >&2
    exit 3
fi

echo
echo "settled. $B"
sed -n '/^== summary ==/,$p' "$B"
