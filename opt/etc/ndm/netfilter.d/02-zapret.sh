#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

[ "$type" = "iptables" ] || exit 0
[ "$table" = "mangle" ] || exit 0

ZAPRET_BASE="${ZAPRET_BASE:-/opt/zapret}"
SCRIPT="${SCRIPT:-"$ZAPRET_BASE/init.d/sysv/zapret"}"

pgrep -f "$ZAPRET_BASE" >/dev/null 2>&1 || exit 0

$SCRIPT start-fw >/dev/null
