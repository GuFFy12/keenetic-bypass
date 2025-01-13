#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

if [ "$type" != "iptables" ] || [ "$table" != "mangle" ]; then
	exit 0
fi

ZAPRET_BASE="${ZAPRET_BASE:-/opt/zapret}"
SCRIPT="${SCRIPT:-"$ZAPRET_BASE/init.d/sysv/zapret"}"

if ! pgrep -f "$ZAPRET_BASE" >/dev/null; then
	exit 0
fi

"$SCRIPT" start-fw >/dev/null
