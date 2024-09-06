#!/bin/sh

SCRIPT=$(readlink -f "$0")
DNSMASQ_ROUTING_BASE=$(dirname "$SCRIPT")
. "$DNSMASQ_ROUTING_BASE/functions.sh"

do_start() {
	dnsmasq_start
	ipset_create
	[ "$SAVE_IPSET_TABLE" = "1" ] && ipset_restore
	ip_rule_apply
	if ip_link_up; then
		ip_route_interface_apply
	elif [ "$KILL_SWITCH" = "1" ]; then
		ip_route_blackhole_apply
	fi
	iptables_apply_rules
}

do_stop() {
	iptables_unapply_rules
	ip_route_interface_unapply
	ip_route_blackhole_unapply
	ip_rule_unapply
	[ "$SAVE_IPSET_TABLE" = "1" ] && ipset_save
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
	N=/etc/init.d/$NAME
	echo "Usage: $N {start|stop|restart|save|restore|flush}" >&2
	exit 1
	;;
esac

exit 0
