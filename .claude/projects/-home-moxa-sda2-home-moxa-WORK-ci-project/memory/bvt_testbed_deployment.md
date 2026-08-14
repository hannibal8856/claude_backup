---
name: BVT testbed multi-DUT deployment status
description: BVT testbed PC deployment state — veth+bridge scheme validated, VLAN assignments, container naming, scripts location, systemd watcher
type: project
originSessionId: 4bc99c17-b20b-4235-9a17-dd54bfbb6d85
---
BVT testbed PC (`switch-rd-testbed`, user `switch_rd_testbed`) hosts multi-DUT containers sharing the same management IP 192.168.127.20 via per-VLAN isolation. Veth+bridge design validated end-to-end on 2026-04-22 (RKS/MDS ping to DUT and NPort confirmed working).

**Why:** Each DUT has fixed management IP 192.168.127.253; containers need the same IP (192.168.127.20) so automation code stays identical across DUTs. VLAN isolates the /24 subnet per-DUT.

**How to apply:** When adding a new model or debugging the testbed, consult this layout first.

## VLAN + IP allocation (from `BVT_PC/bvt_network_config.sh`)

| Model                 | VLAN | IP_120 (NPort) | IP_127 (DUT) | Container name                        |
|-----------------------|------|----------------|--------------|---------------------------------------|
| rks-g4000-l3          | 10   | 192.168.120.48 | 192.168.127.20 | synergy_switch_rks-g4000-l3_bvt     |
| mds-g4000-l3          | 11   | 192.168.120.65 | 192.168.127.20 | synergy_switch_mds-g4000-l3_bvt     |
| tn-4500b              | 12   | 192.168.120.70 | 192.168.127.20 | synergy_switch_tn-4500b_bvt         |
| mds-g4000-4xgs        | 13   | 192.168.120.69 | 192.168.127.20 | synergy_switch_mds-g4000-4xgs_bvt   |
| mds-g4000-l3-4xgs     | 14   | 192.168.120.67 | 192.168.127.20 | synergy_switch_mds-g4000-l3-4xgs_bvt|
| rks-g4000             | 15   | 192.168.120.68 | 192.168.127.20 | synergy_switch_rks-g4000_bvt        |
| mds-g4000             | 16   | 192.168.120.66 | 192.168.127.20 | synergy_switch_mds-g4000_bvt        |
| tsn                   | 17   | 192.168.120.72 | 192.168.127.20 | synergy_switch_tsn_bvt              |
| eds-g4000             | 18   | 192.168.120.71 | 192.168.127.20 | synergy_switch_eds-g4000_bvt        |
| 65m-5011m             | 19   | 192.168.120.73 | 192.168.127.20 | synergy_switch_65m-5011m_bvt        |
| mrx-q4000-l3          | 20   | 192.168.120.74 | 192.168.127.20 | synergy_switch_mrx-q4000-l3_bvt     |
| rks-g4000-pl          | 21   | 192.168.120.75 | 192.168.127.20 | synergy_switch_rks-g4000-pl_bvt     |
| rks-g4000-pl-l3       | 22   | 192.168.120.76 | 192.168.127.20 | synergy_switch_rks-g4000-pl-l3_bvt  |

NPort VLAN = 100 (shared, 192.168.120.254). Trunk interface = `enp2s0`.

## Key paths on BVT host

- Scripts: `/home/switch_rd_testbed/bvt_network_env/` (migrated from `~/oscartu/brainstorm/` on 2026-04-23)
- Host VLAN snippets: `/etc/network/interfaces.d/bvt-common.cfg` + `bvt-<model>.cfg`
- Container material (per model): `/home/switch_rd_testbed/material/synergy_switch_<model>_bvt/`
- Shared code (bind mount): `/home/switch_rd_testbed/switch_synergyautomation/`
- Image: `registry.gitlab.com/moxa/qa/product/switch/switch_infra/switch_synergy:v0.10-r3.3.2`
- Container Docker network: `mgmt_net` (default bridge for internet; veth added by setup script)

## Systemd watcher

`bvt-container-network.service` runs `bvt_container_network_watcher.sh`, which listens to `docker events --filter event=start` and re-runs `setup_bvt_container_network.sh <model>` on every container start (boot, `docker start`, `docker restart`). Host VLAN/bridge persists via `/etc/network/interfaces.d/`; only veth + in-namespace IPs need re-attach.

## Backup containers

`synergy_switch_rks-g4000-l3_bvt_macvlan` — the original RKS container (Docker macvlan on `vlan10_net`, IP 192.168.127.129) renamed as backup before the veth rebuild. To roll back RKS: stop veth version, rename macvlan back to original name, `docker start`.

## Container run flags gotcha

Must use `docker run -dit` (not just `-d`). The image's entrypoint `tftp_configure.sh` `exec`s to `bash`; without a tty, bash hits EOF immediately, `--restart always` restart-loops. Confirmed via log "使用提供的 CONTAINER_IP ... 正在配置 TFTP 服務器" repeating endlessly.
