#!/bin/sh

SCRIPT=$(readlink -f "$0")
DNSMASQ_ROUTING_BASE=$(dirname "$SCRIPT")
. "$DNSMASQ_ROUTING_BASE/functions.sh"

do_start() {
	dnsmasq_start
	ipset_create
	[ "$IPSET_TABLE_SAVE" = "1" ] && ipset_restore
	iptables_apply_rules
	ip_rule_apply
	ip_route_interface_apply
	[ "$KILL_SWITCH" = "1" ] && ip_route_blackhole_apply
}

do_stop() {
	ip_rule_unapply
	iptables_unapply_rules
	[ "$IPSET_TABLE_SAVE" = "1" ] && ipset_save
	ipset_destroy
	dnsmasq_stop
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

save)
	ipset_save
	;;

restore)
	ipset_restore
	;;

flush)
	ipset_flush
	;;

*)
	echo "Usage: $SCRIPT {start|stop|restart|save|restore|flush}" >&2
	exit 1
	;;
esac

exit 0
