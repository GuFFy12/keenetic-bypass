#!/bin/sh

. /opt/etc/dnsmasq_routing.conf

[ "$type" = "iptables" ] || exit 0
[ "$table" = "mangle" ] || exit 0

[ -n "$(ipset --quiet list "$TABLE")" ] || exit 0
ip rule list | grep -q "lookup $MARK" || exit 0
[ -n "$(ip route list table "$MARK")" ] || exit 0

ipta()
{
	iptables -C "$@" > /dev/null 2>&1 || iptables -A "$@"
}

ipta PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m conntrack --ctstate NEW -m set --match-set "$TABLE" dst -j CONNMARK --set-mark "$MARK"
ipta PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m set --match-set "$TABLE" dst -j CONNMARK --restore-mark
