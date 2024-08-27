#!/bin/sh

[ "$type" = "ip6tables" ] && exit 0
[ "$table" != "mangle" ] && exit 0

if pgrep -f /opt/zapret/ > /dev/null; then
	/opt/zapret/init.d/sysv/zapret start-fw
fi
