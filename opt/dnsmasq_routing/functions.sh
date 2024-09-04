#!/bin/sh

DNSMASQ_ROUTING_BASE=${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}
DNSMASQ_ROUTING_CONF_FILE=${DNSMASQ_ROUTING_CONF_FILE:-$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf}
. "$DNSMASQ_ROUTING_CONF_FILE"
DNSMASQ_CONF_FILE=${DNSMASQ_CONF_FILE:-$DNSMASQ_ROUTING_BASE/dnsmasq.conf}
DNSMASQ_PID_FILE=${DNSMASQ_PID_FILE:-/opt/var/run/dnsmasq-5300.pid}
IPSET_RULES_FILE=${IPSET_RULES_FILE:-$DNSMASQ_ROUTING_BASE/ipset_$IPSET_TABLE.rules}

on_off_function()
{
	# $1 : function name on
	# $2 : function name off
	# $3 : 0 - off, 1 - on
	local fun="$1"
	[ "$3" = "1" ] || fun="$2"
	shift
	shift
	shift
	$fun "$@"
}

iptables_rule_exists()
{
	[ -z "$(iptables -C "$@" 2>&1)" ]
}

iptables_rule_add()
{
	iptables_rule_exists "$@" || iptables -A "$@"
}

iptables_rule_delete()
{
	iptables_rule_exists "$@" && iptables -D "$@"
}

iptables_rules()
{
	# $1 - 1 - add, 0 - delete
	on_off_function iptables_rule_add iptables_rule_delete "$1" PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m conntrack --ctstate NEW -m set --match-set "$IPSET_TABLE" dst -j CONNMARK --set-mark "$MARK"
	on_off_function iptables_rule_add iptables_rule_delete "$1" PREROUTING -w -t mangle ! -s "$INTERFACE_SUBNET" -m set --match-set "$IPSET_TABLE" dst -j CONNMARK --restore-mark
}

iptables_apply_rules()
{
	iptables_rules 1
}

iptables_unapply_rules()
{
	iptables_rules 0
}

ip_route_exists()
{
	# $1 - ip route
	local ip_route=${1:-.}
	ip route list table "$MARK" | grep -q "$ip_route"
}

ip_link_up()
{
	[ -n "$(ip link show t2s_br0 up)" ]
}

ip_route_blackhole_apply()
{
	ip_route_exists "blackhole default" || ip route add blackhole default table "$MARK"
}

ip_route_blackhole_unapply()
{
	ip_route_exists "blackhole default" && ip route del blackhole default table "$MARK"
}

ip_route_interface_apply()
{
	if ip_link_up && ! ip_route_exists; then
		ip route add default dev "$INTERFACE" table "$MARK"
	fi
}

ip_route_interface_unapply()
{
	if ip_link_up && ip_route_exists; then
		ip route del default dev "$INTERFACE" table "$MARK"
	fi
}

ip_rule_exists()
{
	ip rule list | grep -q "lookup $MARK"
}

ip_rule_apply()
{
	ip_rule_exists || ip rule add fwmark "$MARK" table "$MARK"
}

ip_rule_unapply()
{
	ip_rule_exists && ip rule del fwmark "$MARK" table "$MARK"
}

ipset_exists()
{
	[ -n "$(ipset -q list "$IPSET_TABLE")" ]
}

ipset_create()
{
	ipset_exists || ipset create "$IPSET_TABLE" hash:ip timeout "$IPSET_TIMEOUT"
}

ipset_destroy()
{
	ipset_exists && ipset destroy "$IPSET_TABLE"
}

ipset_save()
{
	ipset_exists && ipset save blocklist | tail -n +2 > "$IPSET_RULES_FILE"
}

ipset_restore()
{
	if ipset_exists && [ -f "$IPSET_RULES_FILE" ]; then
		ipset restore -exist < "$IPSET_RULES_FILE"
	fi
}

ipset_flush()
{
	ipset_exists && ipset flush "$IPSET_TABLE"
}

dnsmasq_pid_file_exists()
{
	[ -f "$DNSMASQ_PID_FILE" ]
}

dnsmasq_exists()
{
	dnsmasq_pid_file_exists && [ -z "$(kill -0 "$(cat "$DNSMASQ_PID_FILE")" 2>&1)" ]
}

dnsmasq_start()
{
	dnsmasq_exists || dnsmasq --conf-file="$DNSMASQ_CONF_FILE"
}

dnsmasq_stop()
{
	dnsmasq_exists && kill "$(cat "$DNSMASQ_PID_FILE")"
	dnsmasq_pid_file_exists && unlink "$DNSMASQ_PID_FILE"
}
