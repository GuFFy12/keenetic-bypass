#!/bin/sh

. /opt/etc/dnsmasq_routing.conf

[ "$1" = "hook" ] || exit 0
[ "$system_name" = "$INTERFACE" ] || exit 0
[ "$layer" = "link" ] || exit 0

if [ "$level" = "running" ]; then
	/opt/etc/dnsmasq_routing.sh start
else
	/opt/etc/dnsmasq_routing.sh stop
fi
