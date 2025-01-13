#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

if [ "$1" != "hook" ] || [ "$system_name" != "$INTERFACE" ] || [ "$layer" != "link" ]; then
	exit 0
fi

DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
. "$DNSMASQ_ROUTING_BASE/functions.sh"

if [ "$level" = "running" ]; then
	ip_route_blackhole_unapply
	ip_route_interface_apply
elif [ "$KILL_SWITCH" = "1" ]; then
	ip_route_blackhole_apply
fi
