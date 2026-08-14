#!/usr/bin/env bash
# DUT console wrapper. Validates env, delegates to expect.
# Usage: run.sh "<cmd1>" "<cmd2>" ...

set -euo pipefail

if [ "$#" -lt 1 ]; then
    cat >&2 <<EOF
Usage: $0 "<cmd1>" ["<cmd2>" ...]
Each command is a positional argument; expect drives the console
and waits for a prompt between commands.
EOF
    exit 1
fi

DEVICE="${DUT_CONSOLE_DEV:-/dev/ttyS0}"

if [ ! -e "$DEVICE" ]; then
    echo "ERROR: $DEVICE does not exist" >&2
    exit 1
fi

if [ ! -r "$DEVICE" ] || [ ! -w "$DEVICE" ]; then
    cat >&2 <<EOF
ERROR: cannot read/write $DEVICE
Current user is not in the 'dialout' group. One-time setup:

    sudo usermod -aG dialout \$USER
    # then log out + log back in, OR run: newgrp dialout

Then retry this command.
EOF
    exit 1
fi

# Make sure no other process is holding the line (minicom, screen, picocom).
if command -v fuser >/dev/null 2>&1 && fuser "$DEVICE" >/dev/null 2>&1; then
    echo "ERROR: $DEVICE is in use by another process:" >&2
    fuser -v "$DEVICE" 2>&1 | sed 's/^/  /' >&2
    echo "Close that session (e.g. exit minicom with C-a x) and retry." >&2
    exit 1
fi

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
exec expect "$DIR/drive.exp" "$@"
