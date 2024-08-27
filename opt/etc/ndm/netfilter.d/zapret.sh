#!/bin/sh

[ "$type" = "ip6tables" ] && exit 0
[ "$table" != "mangle" ] && exit 0

[ -n "$(pgrep -f /opt/zapret/)" ] || exit 0

/opt/zapret/init.d/sysv/zapret start-fw
