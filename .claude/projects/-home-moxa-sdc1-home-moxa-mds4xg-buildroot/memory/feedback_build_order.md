---
name: feedback-build-order
description: Buildroot rebuild order — plugin_moxa_snmp must be rebuilt before rust_moxa_build (then final make)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f799ca36-ae55-4954-a42d-21c79180a90b
---

Buildroot rebuild order for mds4xg (and likely other Moxa products on this tree):

```
make 3rdparty_net_snmp-rebuild
make plugin_moxa_snmp-rebuild        # MUST be before rust_moxa_build-rebuild
make rust_moxa_build-rebuild
make                                  # final image
```

**Why:** User corrected my initial ordering (which had rust_moxa_build before plugin_moxa_snmp). Likely because rust_moxa_build consumes generated/installed artifacts from plugin_moxa_snmp (or the rust glue depends on snmp plugin headers/.so being in staging first). Reversing the order risks a stale-link or rust-build-against-old-snmp-plugin situation, even if neither errors visibly.

**How to apply:** Any time the user asks for a chained rebuild that touches both `plugin_moxa_snmp` and `rust_moxa_build`, put `plugin_moxa_snmp-rebuild` first. The full chain above is the canonical sequence after editing C in 3rdparty_net_snmp + plugin_moxa_snmp.
