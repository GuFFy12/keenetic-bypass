#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
DNSMASQ_ROUTING_CONF_FILE="${DNSMASQ_ROUTING_CONF_FILE:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf"}"
. "$DNSMASQ_ROUTING_CONF_FILE"
IPSET_TABLE_RULES_FILE="${IPSET_TABLE_RULES_FILE:-"$DNSMASQ_ROUTING_BASE/ipset_$IPSET_TABLE.rules"}"

ipset_rules_file_exists() {
	[ -f "$IPSET_TABLE_RULES_FILE" ]
}

ipset_exists() {
	ipset -q list "$IPSET_TABLE" >/dev/null
}

ipset_create() {
	if ! ipset_exists; then
		ipset create "$IPSET_TABLE" hash:ip timeout "$IPSET_TABLE_TIMEOUT"
	fi
}

ipset_destroy() {
	if iptables_rule_exists "$IPTABLES_RULE_SET_MARK" || iptables_rule_exists "$IPTABLES_RULE_RESTORE_MARK"; then
		echo "Cannot destroy ipset: iptables rules exist" >&2
		return 1
	elif ipset_exists; then
		ipset destroy "$IPSET_TABLE"
	fi
}

ipset_save() {
	if ! ipset_exists; then
		echo "Cannot save ipset: ipset does not exist" >&2
		return 1
	fi
	ipset save "$IPSET_TABLE" | tail -n +2 >"$IPSET_TABLE_RULES_FILE"
}

ipset_restore() {
	if ! ipset_exists; then
		echo "Cannot restore ipset: ipset does not exist" >&2
		return 1
	elif ipset_rules_file_exists; then
		ipset restore -exist <"$IPSET_TABLE_RULES_FILE"
	fi
}

IPTABLES_RULE_SET_MARK="PREROUTING -w -t mangle ! -s $INTERFACE_SUBNET -m conntrack --ctstate NEW -m set --match-set $IPSET_TABLE dst -j CONNMARK --set-mark $MARK"
IPTABLES_RULE_RESTORE_MARK="PREROUTING -w -t mangle ! -s $INTERFACE_SUBNET -m set --match-set $IPSET_TABLE dst -j CONNMARK --restore-mark"

iptables_rule_exists() {
	eval iptables -C "$@" >/dev/null 2>&1
}

iptables_rule_add() {
	if ! iptables_rule_exists "$@"; then
		eval iptables -A "$@"
	fi
}

iptables_rule_delete() {
	if iptables_rule_exists "$@"; then
		eval iptables -D "$@"
	fi
}

iptables_apply_rules() {
	if ! ipset_exists; then
		echo "Cannot apply iptables rules: ipset does not exist" >&2
		return 1
	fi
	iptables_rule_add "$IPTABLES_RULE_SET_MARK"
	iptables_rule_add "$IPTABLES_RULE_RESTORE_MARK"
}

iptables_unapply_rules() {
	iptables_rule_delete "$IPTABLES_RULE_SET_MARK"
	iptables_rule_delete "$IPTABLES_RULE_RESTORE_MARK"
}

ip_rule_exists() {
	ip rule list | grep -qw "from all fwmark $(printf "0x%x" "$MARK") lookup $MARK"
}

ip_rule_apply() {
	if ! ip_rule_exists; then
		ip rule add fwmark "$MARK" table "$MARK"
	fi
}

ip_rule_unapply() {
	if ip_rule_exists; then
		ip rule del fwmark "$MARK" table "$MARK"
	fi
}

ip_route_exists() {
	ip route list table "$MARK" | grep -q "^${1:-.}"
}

ip_route_blackhole_exists() {
	ip_route_exists "blackhole default"
}

ip_route_dev_exists() {
	ip_route_exists "default dev $INTERFACE"
}

ip_link_up() {
	[ -n "$(ip link show "$INTERFACE" up)" ]
}

ip_route_blackhole_apply() {
	if ! ip_route_exists; then
		ip route add blackhole default table "$MARK"
	fi
}

ip_route_blackhole_unapply() {
	if ip_route_blackhole_exists; then
		ip route del blackhole default table "$MARK"
	fi
}

ip_route_interface_apply() {
	if ! ip_link_up; then
		echo "Cannot apply ip route: interface is down" >&2
		return 1
	elif ! ip_route_exists; then
		ip route add default dev "$INTERFACE" table "$MARK"
	fi
}

ip_route_interface_unapply() {
	if ip_route_dev_exists; then
		ip route del default dev "$INTERFACE" table "$MARK"
	fi
}
