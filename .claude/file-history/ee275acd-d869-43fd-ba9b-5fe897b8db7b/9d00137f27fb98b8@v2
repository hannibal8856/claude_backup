#!/bin/bash
# walk.sh <root-oid> [reps] [label]
#
# Times N snmpwalks of one subtree from the PC and reports the median.
# Absolute /usr/bin path is deliberate: ~/.local/bin/snmpwalk is a pysnmp
# build that hangs and returns 0 varbinds, which looks like a dead DUT.
set -u

OID=${1:?usage: walk.sh <root-oid> [reps] [label]}
REPS=${2:-9}
LABEL=${3:-arm}
HOST=${DUT:-192.168.127.253}
COMM=${COMMUNITY:-public}

SNMPWALK=/usr/bin/snmpwalk
[ -x "$SNMPWALK" ] || { echo "FATAL: $SNMPWALK missing"; exit 1; }

OUT=$(mktemp)
RAW=$(mktemp)
trap 'rm -f "$OUT" "$RAW"' EXIT

echo "=== $LABEL  $OID  (${REPS} reps, host $HOST)"
for i in $(seq "$REPS"); do
    t0=$(date +%s.%N)
    "$SNMPWALK" -v2c -c "$COMM" -On -t 5 "$HOST" "$OID" 2>/dev/null > "$RAW"
    t1=$(date +%s.%N)
    n=$(wc -l < "$RAW")
    printf "%s %s\n" "$n" "$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')" >> "$OUT"
    printf "  rep %-2s vb=%-5s %ss\n" "$i" "$n" "$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')"
done

VBS=$(awk '{print $1}' "$OUT" | sort -u | tr '\n' ',' | sed 's/,$//')
MED=$(awk '{print $2}' "$OUT" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}')
WORST=$(awk '{print $2}' "$OUT" | sort -n | tail -1)
BEST=$(awk '{print $2}' "$OUT" | sort -n | head -1)

# Distinct column OIDs, approximated by stripping the final numeric sub-id.
# Over-counts tables whose INDEX spans several sub-ids (ifRcvAddressTable,
# mxFiberCheck), so completeness against another build must still be judged by
# the MIB object set -- see ADR-0017. Reported here only as a change detector.
COLS=$(sed 's/\.[0-9]* = .*//' "$RAW" | sort -u | wc -l)

echo "  ---"
echo "  varbinds : $VBS"
echo "  median   : ${MED}s   (best ${BEST}s / worst ${WORST}s, n=$REPS)"
echo "  columns~ : $COLS   (approximation -- compare MIB objects for completeness)"

case "$VBS" in
    *,*) echo "  >>> INVALID: varbind count varied across reps -- the walk aborted"
         echo "      early on at least one rep. Investigate before using any timing."
         exit 2 ;;
esac
