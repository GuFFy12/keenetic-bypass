#!/bin/sh

. /opt/etc/dnsmasq_routing.conf

[ "$type" = "ip6tables" ] && exit
[ "$table" != "mangle" ] && exit

[ -n "$(ipset --quiet list "$TABLE")" ] || exit
ip rule list | grep -q "lookup $MARK" || exit
[ -n "$(ip route list table "$MARK")" ] || exit

ipta()
{
	iptables -C "$@" > /dev/null 2>&1 || iptables -A "$@"
}

ipta PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m conntrack --ctstate NEW -m set --match-set "$TABLE" dst -j CONNMARK --set-mark "$MARK"
ipta PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m set --match-set "$TABLE" dst -j CONNMARK --restore-mark
