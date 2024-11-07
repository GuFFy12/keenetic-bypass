DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
DNSMASQ_ROUTING_CONF_FILE="${DNSMASQ_ROUTING_CONF_FILE:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf"}"
. "$DNSMASQ_ROUTING_CONF_FILE"
DNSMASQ_CONF_FILE="${DNSMASQ_CONF_FILE:-"$DNSMASQ_ROUTING_BASE/dnsmasq.conf"}"
DNSMASQ_PID_FILE="${DNSMASQ_PID_FILE:-/opt/var/run/dnsmasq.pid}"
IPSET_TABLE_RULES_FILE="${IPSET_TABLE_RULES_FILE:-"$DNSMASQ_ROUTING_BASE/ipset_$IPSET_TABLE.rules"}"

dnsmasq_pid_file_exists() {
	[ -f "$DNSMASQ_PID_FILE" ]
}

dnsmasq_exists() {
	dnsmasq_pid_file_exists && kill -0 "$(cat "$DNSMASQ_PID_FILE")" >/dev/null 2>&1
}

dnsmasq_start() {
	dnsmasq_exists || dnsmasq --conf-file="$DNSMASQ_CONF_FILE"
}

dnsmasq_stop() {
	dnsmasq_exists && kill "$(cat "$DNSMASQ_PID_FILE")" && unlink "$DNSMASQ_PID_FILE"
}

ipset_rules_file_exists() {
	[ -f "$IPSET_TABLE_RULES_FILE" ]
}

ipset_exists() {
	ipset -q list "$IPSET_TABLE" >/dev/null 2>&1
}

ipset_create() {
	ipset_exists || ipset create "$IPSET_TABLE" hash:ip timeout "$IPSET_TABLE_TIMEOUT"
}

ipset_destroy() {
	if iptables_rules_exists; then
		echo "Cannot destroy ipset: iptables rules exist" >&2
		return 1
	fi
	ipset_exists && ipset destroy "$IPSET_TABLE"
}

ipset_flush() {
	if ! ipset_exists; then
		echo "Cannot flush ipset: ipset does not exist" >&2
		return 1
	fi
	ipset flush "$IPSET_TABLE"
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
	fi
	ipset_rules_file_exists && ipset restore -exist <"$IPSET_TABLE_RULES_FILE"
}

IPTABLES_RULE_SET_MARK="PREROUTING -w -t mangle ! -s $INTERFACE_SUBNET -m conntrack --ctstate NEW -m set --match-set $IPSET_TABLE dst -j CONNMARK --set-mark $MARK"
IPTABLES_RULE_RESTORE_MARK="PREROUTING -w -t mangle ! -s $INTERFACE_SUBNET -m set --match-set $IPSET_TABLE dst -j CONNMARK --restore-mark"

iptables_rule_exists() {
	eval iptables -C "$@" >/dev/null 2>&1
}

iptables_rules_exists() {
	iptables_rule_exists "$IPTABLES_RULE_SET_MARK" || iptables_rule_exists "$IPTABLES_RULE_RESTORE_MARK"
}

iptables_rule_add() {
	iptables_rule_exists "$@" || eval iptables -A "$@"
}

iptables_rule_delete() {
	iptables_rule_exists "$@" && eval iptables -D "$@"
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
	ip rule list | grep -q "from all fwmark $(printf "0x%x" "$MARK") lookup $MARK"
}

ip_rule_apply() {
	ip_rule_exists || ip rule add fwmark "$MARK" table "$MARK"
}

ip_rule_unapply() {
	ip_rule_exists && ip rule del fwmark "$MARK" table "$MARK"
}

ip_route_exists() {
	ip route list table "$MARK" | grep -q "${1:-.}"
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
	ip_route_exists || ip route add blackhole default table "$MARK"
}

ip_route_blackhole_unapply() {
	ip_route_blackhole_exists && ip route del blackhole default table "$MARK"
}

ip_route_interface_apply() {
	if ! ip_link_up; then
		echo "Cannot apply ip route: interface is down" >&2
		return 1
	fi
	ip_route_exists || ip route add default dev "$INTERFACE" table "$MARK"
}

ip_route_interface_unapply() {
	ip_route_dev_exists && ip route del default dev "$INTERFACE" table "$MARK"
}
