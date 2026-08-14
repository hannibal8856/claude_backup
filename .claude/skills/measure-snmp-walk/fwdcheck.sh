#!/bin/bash
# fwdcheck.sh <TARGET_OID> <POSITIVE_OID> <NEGATIVE_OID> [N] [IDLE] [PEER]
#
# Copies fwdcheck_remote.sh to the DUT and runs it there. Everything that
# matters happens on the device, because the AgentX traffic is on its loopback.
#
# PEER picks which subagent to watch (default ISS; use app_moxa_framew for the
# framework subagent). Both share :705, so the choice matters.
set -u

TARGET=${1:?usage: fwdcheck.sh <target> <positive> <negative> [N] [IDLE] [PEER]}
POS=${2:?missing POSITIVE control OID -- it is not optional, see SKILL.md}
NEG=${3:?missing NEGATIVE control OID -- it is not optional, see SKILL.md}
N=${4:-150}
IDLE=${5:-15}
PEER=${6:-ISS}
LABEL=${7:-fwdcheck}   # goes into the retrieved pcap filename

export DUT=${DUT:-192.168.127.253}
HERE=$(cd "$(dirname "$0")" && pwd)

command -v expect >/dev/null || { echo "FATAL: expect not installed"; exit 1; }

echo "copying fwdcheck_remote.sh to $DUT ..."
expect -c "
set timeout 120
log_user 0
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no $HERE/fwdcheck_remote.sh admin@$DUT:/tmp/
expect -re {[Pp]assword:} { send \"moxa\r\" }
expect eof
" || { echo "FATAL: scp failed"; exit 1; }

expect "$HERE/dutssh.exp" \
    "sh /tmp/fwdcheck_remote.sh $TARGET $POS $NEG $N $IDLE $PEER" \
  2>&1 | sed -n -e '/watching peer/,/capture left at/p' \
                -e '/^INVALID/p'

# Retrieve the capture. A packet count in a report is a claim; the pcap is the
# evidence, and the next run overwrites /tmp/fwdcheck.pcap. Pull it before any
# handback cleanup deletes it (ADR-0027 rule 4).
OUTDIR=${PCAPDIR:-$HOME/pcap}
mkdir -p "$OUTDIR"
BUILD=$(expect "$HERE/dutssh.exp" 'cat /etc/moxa/version/BUILD_TIME' 2>/dev/null \
        | grep -oE '20[0-9]{2}_[0-9]{4}_[0-9]{4}' | head -1)
SLUG=$(echo "${LABEL:-fwdcheck}-$PEER" | tr -c 'A-Za-z0-9._-' '-')
OUT="$OUTDIR/$(date +%Y-%m-%d)-${SLUG}-${BUILD:-unknown}.pcap"
expect -c "
set timeout 300
log_user 0
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no admin@$DUT:/tmp/fwdcheck.pcap $OUT
expect -re {[Pp]assword:} { send \"moxa\r\" }
expect eof
" >/dev/null 2>&1
expect -c "
set timeout 120
log_user 0
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no admin@$DUT:/tmp/fwdcheck.err $OUT.tcpdump.log
expect -re {[Pp]assword:} { send \"moxa\r\" }
expect eof
" >/dev/null 2>&1
if [ -s "$OUT" ]; then
    editcap -F pcapng "$OUT" "${OUT%.pcap}.pcapng" 2>/dev/null && { mv -f "$OUT.tcpdump.log" "${OUT%.pcap}.pcapng.tcpdump.log" 2>/dev/null; rm -f "$OUT"; OUT="${OUT%.pcap}.pcapng"; }
    echo "pcap retrieved: $OUT ($(tcpdump -r "$OUT" 2>/dev/null | wc -l) packets)"
    [ -s "$OUT.tcpdump.log" ] && echo "capture: $(grep -oE '[0-9]+ packets (captured|dropped by kernel)' "$OUT.tcpdump.log" | tr '\n' ' ')" || echo "*** .tcpdump.log NOT retrieved ***"
    expect "$HERE/dutssh.exp" "rm -f /tmp/fwdcheck.pcap /tmp/fwdcheck.err" >/dev/null 2>&1
else
    echo "*** pcap NOT retrieved -- /tmp/fwdcheck.pcap left on the DUT, do not clean it ***"
fi
