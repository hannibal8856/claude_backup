---
name: dut-console
description: Drive the serial console at /dev/ttyS0 connected to the Moxa MDS-G4000-L3-4XGS DUT. Logs in as admin/moxa, su's to root (password moxa) if at a Linux shell, runs the provided commands, and writes all I/O to ~/console_<date>_<time>.log. Use when the user asks to run commands on the DUT, verify behavior on the physical device, check device state via console, or snmpwalk/snmpset against the connected hardware.
---

# DUT Serial Console (Moxa MDS-G4000-L3-4XGS)

This skill lets you (Claude) run shell commands on the device under test
connected to /dev/ttyS0 — without an interactive TUI.

## Prerequisites (one-time setup the user must run)

The skill talks to /dev/ttyS0 directly via `picocom`. The current user
needs the `dialout` group:

```bash
sudo usermod -aG dialout $USER
# log out + log back in, OR run `newgrp dialout` in the current shell
```

If you (Claude) call `run.sh` and the user hasn't done this yet, the
script will exit with a clear instruction. Tell the user the command,
do not try to `sudo` your way around it.

## Standing authorization (granted 2026-08-06)

The user has authorized running commands on the DUT without asking each time,
in three tiers. **Always say which tier an action falls under before running
it**, so the user can see what is about to happen.

| Tier | Scope | Ask first? |
|---|---|---|
| **A — read-only** | `snmpget`/`snmpwalk`/`snmpgetnext`, `tcpdump`, `cat`, `ls`, `ps`, `fw_printenv`, reading logs | No |
| **B — changes device state** | editing `/etc/moxa/netsnmp/agentx_owned.list`, restarting snmpd, `snmpset`, config changes via `moxash` | No |
| **C — firmware** | `fwr_change.sh` partition switch, `swupdate` of a `.swu` to verify Plan E changes | No |

Tier C does **not** waive the guardrails in `examinate-plan-e-swu`: `--protect 2`
and `--control-build 2026_0805_2335` stay on. Flashing is always done **from**
the mainline control group so the write lands on partition 1. Passing
`--protect none` or `--control-build none` is outside this authorization and
still needs the user to say so explicitly.

Anything not listed — reformatting storage, changing credentials, factory
reset, touching a device other than `192.168.127.253` — is not covered.

**Prefer the network over the serial console.** Most work needs no console at
all: SNMP queries run from this host directly (use `/usr/bin/snmpwalk`, not
`~/.local/bin/snmpwalk` — that one is pysnmp and will hang). For on-device work,
ssh (port 22, `admin`/`moxa`, `expect` is installed) is faster and cleaner than
serial, and leaves the user's `minicom` session undisturbed. Serial is the
fallback: it is slow, and kernel log messages interleave into command output
and corrupt it.

## How to invoke

```bash
bash ~/.claude/skills/dut-console/run.sh "<cmd1>" "<cmd2>" ...
```

Each command is a positional argument. Examples:

```bash
# Single command
bash ~/.claude/skills/dut-console/run.sh "uname -a"

# Multiple — passed in order, prompt-synced between
bash ~/.claude/skills/dut-console/run.sh \
  "ip -br link" \
  "cat /etc/moxa/netsnmp/agentx_owned.list" \
  "snmpwalk -v2c -c public localhost ifTable | head -20"
```

The wrapper:

1. Spawns `picocom -b 115200 --noinit --noreset /dev/ttyS0`
2. Wakes the console (sends `\r`) and detects current state:
   - `login:`        → sends `admin` + `moxa`
   - `$` prompt      → Linux shell as non-root → sends `su` + `moxa`
   - `#` prompt      → already root (Linux) or ISS privileged → continue
   - `>` prompt      → ISS CLI mode → continue
3. Sends each command, waits for the next prompt
4. Exits picocom cleanly with `C-a C-x`
5. Captures **all** console I/O (including login, password echo, prompts)
   to `~/console_<YYYYMMDD>_<HHMMSS>.log`
6. Prints the log path on stdout

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success — all commands sent, picocom exited cleanly |
| 1 | Bad args / no /dev/ttyS0 access |
| 2 | Login failed (wrong creds or unreachable login prompt) |
| 3 | Could not detect any prompt (device may be off/booting) |
| 4 | `su` failed (wrong password) |
| 5 | Timeout |

## Tuning

Default expect timeout is 15 s per response. For long-running commands
(firmware update, large snmpwalk on slow MIB), edit `set timeout` near
the top of `drive.exp`, OR pre-redirect the slow command into the
background and tail it on subsequent invocations.

## What this skill is NOT for

- Interactive debugging that needs you to read intermediate output and
  decide next commands mid-session — this is fire-and-forget per call.
- Anything that reboots the DUT mid-session (picocom drops on carrier
  loss; subsequent commands will be lost).
- Human-driven console use — the user's existing `mmmmminicom` alias
  (= `sudo minicom -D /dev/ttyS0`) is the right tool for that.

## When to use

Use this skill **without asking** when the user asks you to:
- "Run `<cmd>` on the device"
- "Check `<thing>` on the DUT"
- "Verify the new image actually works"
- "snmpwalk the device"
- "Show me what's in `<file>` on the switch"

Always tell the user the log path you got back so they can inspect it.
