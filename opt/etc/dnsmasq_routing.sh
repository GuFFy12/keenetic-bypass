#!/bin/sh

. /opt/etc/dnsmasq_routing.conf

ipta()
{
	iptables -C "$@" > /dev/null 2>&1 || iptables -A "$@"
}

ipt_del()
{
	iptables -C "$@" > /dev/null 2>&1 && iptables -D "$@"
}

on_off_function()
{
	# $1 : function name on
	# $2 : function name off
	# $3 : 0 - off, 1 - on
	F="$1"
	[ "$3" = "1" ] || F="$2"
	shift
	shift
	shift
	"$F" "$@"
}

fw()
{
	# $1 - 1 - add, 0 - delete
	on_off_function ipta ipt_del "$1" PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m conntrack --ctstate NEW -m set --match-set "$TABLE" dst -j CONNMARK --set-mark "$MARK"
	on_off_function ipta ipt_del "$1" PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m set --match-set "$TABLE" dst -j CONNMARK --restore-mark
}

ipset_exists()
{
    [ -n "$(ipset --quiet list "$TABLE")" ]
}

ip_rule_exists()
{
    ip rule list | grep -q "lookup $MARK"
}

ip_route_exists()
{
    [ -n "$(ip route list table "$MARK")" ]
}

do_start()
{
	ipset_exists || ipset create "$TABLE" hash:ip timeout "$TIMEOUT"
	ip_rule_exists ||	ip rule add fwmark "$MARK" table "$MARK"
	ip_route_exists || ip route add default dev "$INTERFACE" table "$MARK"
	fw 1
}
do_stop()
{
	fw 0
	ip_route_exists && ip route del default dev "$INTERFACE" table "$MARK"
	ip_rule_exists && ip rule del fwmark "$MARK" table "$MARK"
}
do_flush()
{
	ipset_exists && ipset flush "$TABLE"
}
do_stop_ipset()
{
	do_stop
	ipset_exists && ipset destroy "$TABLE"
}

case "$1" in
	start)
		do_start
	;;

	stop)
		do_stop
	;;

	restart)
		do_stop
		do_start
	;;

	flush)
		do_flush
	;;

	stop_ipset)
		do_stop_ipset
	;;

	*)
	N=/etc/init.d/$NAME
	echo "Usage: $N {start|stop|restart|flush|stop_ipset}" >&2
	exit 1
	;;
esac

exit 0
