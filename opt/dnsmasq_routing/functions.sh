DNSMASQ_ROUTING_BASE=${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}
DNSMASQ_ROUTING_CONF_FILE=${DNSMASQ_ROUTING_CONF_FILE:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf"}
. "$DNSMASQ_ROUTING_CONF_FILE"
DNSMASQ_CONF_FILE=${DNSMASQ_CONF_FILE:-"$DNSMASQ_ROUTING_BASE/dnsmasq.conf"}
DNSMASQ_PID_FILE=${DNSMASQ_PID_FILE:-/opt/var/run/dnsmasq-5300.pid}
IPSET_TABLE_RULES_FILE=${IPSET_TABLE_RULES_FILE:-"$DNSMASQ_ROUTING_BASE/ipset_$IPSET_TABLE.rules"}

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
	dnsmasq_exists && kill "$(cat "$DNSMASQ_PID_FILE")"
	dnsmasq_pid_file_exists && unlink "$DNSMASQ_PID_FILE"
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

ipset_flush() {
	ipset_exists && ipset flush "$IPSET_TABLE"
}

ipset_destroy() {
	iptables_rules_exists && return 1
	ipset_exists && ipset destroy "$IPSET_TABLE"
}

ipset_save() {
	ipset_exists && ipset save "$IPSET_TABLE" | tail -n +2 >"$IPSET_TABLE_RULES_FILE"
}

ipset_restore() {
	if ipset_exists && ipset_rules_file_exists; then
		ipset restore -exist <"$IPSET_TABLE_RULES_FILE"
	fi
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
	ipset_exists || return 1
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
	[ -n "$(ip route list table "$MARK")" ]
}

ip_route_blackhole_exists() {
	ip route list table "$MARK" | grep -q "blackhole default"
}

ip_route_dev_exists() {
	ip route list table "$MARK" | grep -q "default dev $INTERFACE"
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
	ip_link_up || return 1
	ip_route_exists || ip route add default dev "$INTERFACE" table "$MARK"
}

ip_route_interface_unapply() {
	ip_route_dev_exists && ip route del default dev "$INTERFACE" table "$MARK"
}
