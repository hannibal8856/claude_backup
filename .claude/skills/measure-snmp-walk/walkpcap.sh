#!/bin/bash
# walkpcap.sh <root-oid> <label> [reps]
#
# Times N snmpwalks of one subtree while capturing the DUT's AgentX loopback
# (:705), then retrieves the capture to ~/pcap/ under the convention the older
# captures already use:  <date>_<label>_<BUILD_TIME>.pcap
#
# The capture is the point. A packet count in a report is a claim; a pcap is
# evidence someone else can re-analyse without the DUT -- which is exactly what
# made the 2026-08-07 mxPort captures able to settle a disputed number three
# days later.
set -u

OID=${1:?usage: walkpcap.sh <root-oid> <label> [reps]}
LABEL=${2:?missing label, e.g. evtPort-planE or evtPort-mainline}
REPS=${3:-9}
HOST=${DUT:-192.168.127.253}
COMM=${COMMUNITY:-public}
HERE=$(cd "$(dirname "$0")" && pwd)
OUTDIR=${PCAPDIR:-$HOME/pcap}

command -v expect >/dev/null || { echo "FATAL: expect not installed"; exit 1; }
mkdir -p "$OUTDIR"

BUILD=$(expect "$HERE/dutssh.exp" 'cat /etc/moxa/version/BUILD_TIME' 2>/dev/null \
        | grep -oE '20[0-9]{2}_[0-9]{4}_[0-9]{4}' | head -1)
[ -n "$BUILD" ] || { echo "FATAL: could not read BUILD_TIME from the DUT"; exit 1; }
# <測試日期>-<feature>-<image build date>.pcapng  (build date is always the last
# field and matches 20\d\d_\d{4}_\d{4}, so a hyphenated feature stays parseable)
OUT="$OUTDIR/$(date +%Y-%m-%d)-${LABEL}-${BUILD}.pcapng"
RAWPCAP="${OUT%.pcapng}.pcap"
echo "DUT $HOST  BUILD_TIME=$BUILD"
echo "capture -> $OUT"

# Self-terminating capture: no kill needed, and it must outlast the walks.
DUR=$(( REPS * 15 + 45 ))
# tcpdump's own stderr is kept: "N packets captured / N received by filter /
# 0 dropped by kernel" is the only thing that distinguishes "the link was quiet"
# from "the capture lost packets". The 2026-08-08 captures keep it as a
# .tcpdump.log sidecar; do the same.
expect "$HERE/dutssh.exp" \
  "rm -f /tmp/walkpcap.pcap /tmp/walkpcap.err; nohup tcpdump -i lo -n -U -w /tmp/walkpcap.pcap -G $DUR -W 1 port 705 >/dev/null 2>/tmp/walkpcap.err & sleep 3; ls -l /tmp/walkpcap.pcap" \
  >/dev/null 2>&1 &
sleep 8

echo "=== $LABEL  $OID  (${REPS} reps) ==="
TMP=$(mktemp); RAW=$(mktemp); trap 'rm -f "$TMP" "$RAW"' EXIT
for i in $(seq "$REPS"); do
    t0=$(date +%s.%N)
    /usr/bin/snmpwalk -v2c -c "$COMM" -On -t 5 "$HOST" "$OID" 2>/dev/null > "$RAW"
    t1=$(date +%s.%N)
    d=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')
    printf "%s %s\n" "$(wc -l < "$RAW")" "$d" >> "$TMP"
    printf "  rep %-2s vb=%-5s %ss\n" "$i" "$(wc -l < "$RAW")" "$d"
done

VBS=$(awk '{print $1}' "$TMP" | sort -u | tr '\n' ',' | sed 's/,$//')
MED=$(awk '{print $2}' "$TMP" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}')
COLS=$(sed 's/\.[0-9]* = .*//' "$RAW" | sort -u | wc -l)
echo "  ---"
echo "  varbinds : $VBS"
echo "  median   : ${MED}s  (n=$REPS)"
echo "  columns~ : $COLS   (approximation -- compare MIB objects for completeness)"

# Let the capture close before pulling it.
sleep "$(( DUR > 60 ? 30 : 10 ))"
expect -c "
set timeout 300
log_user 0
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no admin@$HOST:/tmp/walkpcap.pcap $RAWPCAP
expect -re {[Pp]assword:} { send \"moxa\r\" }
expect eof
" >/dev/null 2>&1

expect -c "
set timeout 120
log_user 0
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o PubkeyAuthentication=no admin@$HOST:/tmp/walkpcap.err $OUT.tcpdump.log
expect -re {[Pp]assword:} { send \"moxa\r\" }
expect eof
" >/dev/null 2>&1

if [ -s "$RAWPCAP" ]; then
    # tcpdump only writes classic pcap; convert on the host.
    editcap -F pcapng "$RAWPCAP" "$OUT" && rm -f "$RAWPCAP"
    echo "  pcap     : $OUT  ($(stat -c %s "$OUT") bytes, $(tcpdump -r "$OUT" 2>/dev/null | wc -l) packets on :705)"
    if [ -s "$OUT.tcpdump.log" ]; then
        echo "  capture  : $(grep -oE '[0-9]+ packets (captured|dropped by kernel)' "$OUT.tcpdump.log" | tr '\n' ' ')"
    else
        echo "  capture  : *** .tcpdump.log NOT retrieved -- cannot prove the capture was lossless ***"
    fi
    expect "$HERE/dutssh.exp" "rm -f /tmp/walkpcap.pcap /tmp/walkpcap.err" >/dev/null 2>&1
else
    echo "  pcap     : *** NOT RETRIEVED -- /tmp/walkpcap.pcap left on the DUT, do not clean it ***"
    exit 3
fi

case "$VBS" in
    *,*) echo "  >>> INVALID: varbind count varied across reps -- the walk aborted early"; exit 2 ;;
esac
