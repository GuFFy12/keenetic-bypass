#!/bin/sh

. /opt/etc/dnsmasq_routing.conf

[ "$1" = "hook" ] || exit 0
[ "$system_name" = "$INTERFACE" ] || exit 0
[ "$layer" = "link" ] || exit 0

ip_route_blackhole_exist()
{
	ip route list table "$MARK" | grep -q "blackhole default"
}

ip_route_exists()
{
  [ -n "$(ip route list table "$MARK")" ]
}

if [ "$level" = "running" ]; then
	ip_route_blackhole_exist && ip route del blackhole default table "$MARK"
	ip_route_exists || ip route add default dev "$INTERFACE" table "$MARK"
elif [ "$KILL_SWITCH" = "1" ]; then
	ip_route_exists || ip route add blackhole default table "$MARK"
fi
