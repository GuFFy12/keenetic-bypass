#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

RELEASE_TAG=v1.1.8

ZAPRET_BASE="${ZAPRET_BASE:-/opt/zapret}"
ZAPRET_SCRIPT="${ZAPRET_SCRIPT:-"$ZAPRET_BASE/init.d/sysv/zapret_keenetic.sh"}"
ZAPRET_CONFIG="${ZAPRET_CONFIG:-"$ZAPRET_BASE/config"}"
ZAPRET_INSTALL_BIN="${ZAPRET_INSTALL_BIN:-"$ZAPRET_BASE/install_bin.sh"}"
ZAPRET_GET_CONFIG="${ZAPRET_GET_CONFIG:-"$ZAPRET_BASE/ipset/get_config.sh"}"

DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
DNSMASQ_ROUTING_SCRIPT="${DNSMASQ_ROUTING_SCRIPT:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.sh"}"
DNSMASQ_ROUTING_CONFIG="${DNSMASQ_ROUTING_CONFIG:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf"}"
DNSMASQ_CONFIG="${DNSMASQ_CONFIG:-/opt/etc/dnsmasq.conf}"

rm_dir() {
	if [ -d "$1" ]; then
		rm -r "$1"
	fi
}

delete_service() {
	if [ -f "$2" ] && ! "$2" stop; then
		echo "Failed to stop service using script: $2" >&2
	fi
	rm_dir "$1"
}

get_zapret_config_iface_wan() {
	ZAPRET_CONFIG_IFACE_WAN="${ZAPRET_CONFIG_IFACE_WAN:-"$(ip route show default 0.0.0.0/0 | awk '{print $5}')"}"

	if [ -z "$ZAPRET_CONFIG_IFACE_WAN" ]; then
		return 1
	fi
}

get_dnsmasq_config_server() {
	dnsmasq_config_server_port="$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"

	if [ -z "$dnsmasq_config_server_port" ]; then
		echo No DNS server found >&2
		return 1
	fi

	DNSMASQ_CONFIG_SERVER="${DNSMASQ_CONFIG_SERVER:-"127.0.0.1#$dnsmasq_config_server_port"}"
}

select_dnsmasq_routing_interface() {
	interfaces=$(ip -o -4 addr show | awk '{print $1 " " $2 " " $4}')

	if [ -z "$interfaces" ]; then
		echo No interfaces found >&2
		return 1
	fi

	echo Interface list:
	echo "$interfaces" | awk '{print $1 " " $2 " (" $3 ")"}'

	echo Enter interface tunnel number for dnsmasq routing:
	read -r choice

	selected_line="$(echo "$interfaces" | awk -F': ' -v choice="$choice" '$1 == choice')"
	DNSMASQ_ROUTING_CONFIG_INTERFACE=$(echo "$selected_line" | awk '{print $2}')
	DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET=$(echo "$selected_line" | awk '{print $3}')

	if [ -z "$DNSMASQ_ROUTING_CONFIG_INTERFACE" ] || [ -z "$DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET" ]; then
		echo Invalid interface choice >&2
		return 1
	fi

	return 0
}

replace_config_value() {
	sed -i "s|^$2=.*|$2=$3|" "$1"
}

add_cron_job() {
	if ! crontab -l 2>/dev/null | grep -Fq "$1"; then
		(
			crontab -l 2>/dev/null
			echo "$1"
		) | crontab -
		echo "Cronjob added: $1"
	else
		echo "Cronjob already exists: $1"
	fi
}

if ! command -v ndmc >/dev/null; then
	echo Command 'ndmc' not found >&2
	exit 1
elif ! NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd '0-9.')"; then
	echo Failed to retrieve NDM version >&2
	exit 1
elif [ -z "$NDM_VERSION" ]; then
	echo Invalid or missing NDM version >&2
	exit 1
elif [ "${NDM_VERSION%%.*}" -lt 4 ]; then
	# ndm/iflayerchanged.d does not exist in versions below 4.0.0
	echo "NDM version $NDM_VERSION is less than 4.0.0" >&2
	exit 1
fi

echo Installing packages...
opkg update && opkg install coreutils-sort cron curl dnsmasq git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy

echo Delete zapret...
delete_service "$ZAPRET_BASE" "$ZAPRET_SCRIPT"

echo Installing Keenetic Bypass...
delete_service "$DNSMASQ_ROUTING_BASE" "$DNSMASQ_ROUTING_SCRIPT"
if [ -n "$(readlink -f "$0")" ]; then
	cp -r opt/* /opt/
else
	TMP_DIR=$(mktemp -d)
	RELEASE_FILE="keenetic-bypass-$RELEASE_TAG.tar.gz"

	curl -f -L -o "$TMP_DIR/$RELEASE_FILE" "https://github.com/GuFFy12/keenetic-bypass/releases/download/$RELEASE_TAG/$RELEASE_FILE"
	tar -xvzf "$TMP_DIR/$RELEASE_FILE" -C "$TMP_DIR" >/dev/null
	cp -r "$TMP_DIR/opt/"* /opt/
	rm -rf "$TMP_DIR"
fi

echo Configuring zapret...
"$ZAPRET_INSTALL_BIN"
"$ZAPRET_GET_CONFIG"

echo Changing the settings...
if ! get_zapret_config_iface_wan; then
	echo Failed to retrieve WAN interface for zapret >&2
	exit 1
elif ! get_dnsmasq_config_server; then
	echo Failed to retrieve DNS server for dnsmasq >&2
	exit 1
elif ! select_dnsmasq_routing_interface; then
	echo Failed to retrieve routing interface for dnsmasq routing >&2
	exit 1
fi

replace_config_value "$ZAPRET_CONFIG" "IFACE_WAN" "$ZAPRET_CONFIG_IFACE_WAN"
replace_config_value "$DNSMASQ_CONFIG" "server" "$DNSMASQ_CONFIG_SERVER"
replace_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE" "$DNSMASQ_ROUTING_CONFIG_INTERFACE"
replace_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE_SUBNET" "$DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET"

echo Configuring cron jobs...
add_cron_job "0 0 * * * $DNSMASQ_ROUTING_SCRIPT save"
add_cron_job "0 0 * * * $ZAPRET_GET_CONFIG"

echo Running zapret...
"$ZAPRET_SCRIPT" start
echo Running dnsmasq routing...
"$DNSMASQ_ROUTING_SCRIPT" start

echo Components have been successfully installed. For further configuration please refer to README.md file!
