---
name: tshark-udp-payload-quirk
description: tshark 3.2.3 on this host cannot extract udp.payload as a field; use raw hex for content scans
metadata: 
  node_type: memory
  type: reference
  originSessionId: 21107fb9-4b06-4160-8295-54471bb95b21
---

On this host the pcap analysis tooling is tshark/tcpdump/capinfos (Wireshark **3.2.3**, in `/home/moxa/sdc1/mnt/.ewsrc/pcap`).

Gotcha: `tshark -T fields -e udp.payload` (also `-e data` / `-e data.data`) returns **empty** even for files that clearly contain UDP packets. So any content-based scan built on field extraction silently produces false negatives.

**How to apply:** For payload/byte-pattern scans (e.g. detecting a protocol on a non-standard port), don't rely on `udp.payload`. Instead dump raw frame hex with `tshark -r f -Y udp -x`, reconstruct per-packet hex (awk: collect `^[0-9a-f]{2}$` tokens, split packets on offset `0000`), then grep the byte signature. Always self-test the detector against a synthetic known-positive first. To confirm a hit is real, force-decode the port: `tshark -r f -d udp.port==N,snmp -Y snmp`.

Concrete result: this folder's SNMP traffic is SNMPv1 traps on **UDP port 164** (not 161/162) — found only in `ipv6_neigh_solicitation.pcap` (9 pkts) and `0524_49186.pcap` (2 pkts).
