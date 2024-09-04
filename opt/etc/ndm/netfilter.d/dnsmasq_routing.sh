#!/bin/sh

[ "$type" = "iptables" ] || exit 0
[ "$table" = "mangle" ] || exit 0

DNSMASQ_ROUTING_BASE=${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}
. "$DNSMASQ_ROUTING_BASE/functions.sh"

ipset_exists || exit 0
ip_rule_exists || exit 0

iptables_apply_rules
