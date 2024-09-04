#!/bin/sh

[ "$type" = "iptables" ] || exit 0
[ "$table" = "mangle" ] || exit 0

ZAPRET_BASE=${ZAPRET_BASE:-/opt/zapret}
SCRIPT=${SCRIPT:-$ZAPRET_BASE/init.d/sysv/zapret}

[ -n "$(pgrep -f "$ZAPRET_BASE")" ] || exit 0

$SCRIPT start-fw > /dev/null
