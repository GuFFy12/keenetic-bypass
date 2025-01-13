#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

if [ "$type" != "iptables" ] || [ "$table" != "mangle" ]; then
	exit 0
fi

DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
. "$DNSMASQ_ROUTING_BASE/functions.sh"

if ! ipset_exists; then
	exit 0
fi

iptables_apply_rules
