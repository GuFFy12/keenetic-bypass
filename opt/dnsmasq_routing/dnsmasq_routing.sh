#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

SCRIPT="$(readlink -f "$0")"
DNSMASQ_ROUTING_BASE="$(dirname "$SCRIPT")"
. "$DNSMASQ_ROUTING_BASE/functions.sh"

do_start() {
	ipset_create
	if [ "$IPSET_TABLE_SAVE" = "1" ]; then
		ipset_restore
	fi
	iptables_apply_rules
	ip_rule_apply
	ip_route_interface_apply
	if [ "$KILL_SWITCH" = "1" ]; then
		ip_route_blackhole_apply
	fi
}

do_stop() {
	ip_rule_unapply
	iptables_unapply_rules
	if [ "$IPSET_TABLE_SAVE" = "1" ]; then
		ipset_save
	fi
	ipset_destroy
}

usage() {
	echo "Usage: $SCRIPT {start|stop|restart|save|restore}" >&2
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi
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

*)
	usage
	;;
esac

exit 0
