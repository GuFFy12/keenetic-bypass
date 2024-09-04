#!/bin/sh

DNSMASQ_ROUTING_BASE=${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}
. "$DNSMASQ_ROUTING_BASE/functions.sh"

[ "$1" = "hook" ] || exit 0
[ "$system_name" = "$INTERFACE" ] || exit 0
[ "$layer" = "link" ] || exit 0

if [ "$level" = "running" ]; then
	ip_route_blackhole_unapply
	ip_route_interface_apply
elif [ "$KILL_SWITCH" = "1" ]; then
	ip_route_blackhole_apply
fi
