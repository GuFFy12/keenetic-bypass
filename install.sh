#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

ZAPRET_VERSION="${ZAPRET_VERSION:-v69.9}"

ZAPRET_URL="${ZAPRET_URL:-"https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz"}"
KEENETIC_BYPASS_URL="${KEENETIC_BYPASS_URL:-https://github.com/GuFFy12/keenetic-bypass.git}"

KEENETIC_BYPASS_TMP_DIR="${KEENETIC_BYPASS_TMP_DIR:-/opt/tmp/keenetic-bypass}"

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
	if [ ! -f "$2" ]; then
		return 0
	elif ! "$2" stop; then
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
	DNSMASQ_CONFIG_SERVER="${DNSMASQ_CONFIG_SERVER:-"127.0.0.1#$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"}"

	if [ -z "$DNSMASQ_CONFIG_SERVER" ]; then
		return 1
	fi
}

select_dnsmasq_routing_interface() {
	interfaces=$(ip -o -4 addr show | awk '{print $2 " " $4}')

	if [ -z "$interfaces" ]; then
		return 1
	fi

	echo "Interface list:"
	echo "$interfaces" | awk '{print NR ") " $1 " (" $2 ")"}'

	echo "Enter number of tunnel interface for dnsmasq routing (default: 1): "
	read -r choice

	if ! [ "$choice" -ge 1 ] 2>/dev/null || [ -z "$choice" ]; then
		choice=1
	fi

	selected_line=$(echo "$interfaces" | awk 'NR=='"$choice"'')
	if [ -z "$selected_line" ]; then
		selected_line=$(echo "$interfaces" | awk 'NR==1')
	fi

	DNSMASQ_ROUTING_CONFIG_INTERFACE=$(echo "$selected_line" | awk '{print $1}')
	DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET=$(echo "$selected_line" | awk '{print $2}')

	if [ -z "$DNSMASQ_ROUTING_CONFIG_INTERFACE" ] || [ -z "$DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET" ]; then
		return 1
	fi
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

ask_yes_no() {
	echo "$2 (default: ${1:-N}) (Y/N): "
	read -r answer

	if [ -z "$answer" ]; then
		answer="${1:-N}"
	fi

	case "$answer" in
	[yY1]) return 0 ;;
	[nN0]) return 1 ;;
	*) return 1 ;;
	esac
}

if ! command -v ndmc >/dev/null; then
	echo "Command 'ndmc' not found" >&2
	exit 1
elif ! NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd '0-9.')"; then
	echo "Failed to retrieve NDM version" >&2
	exit 1
elif [ -z "$NDM_VERSION" ]; then
	echo "Invalid or missing NDM version" >&2
	exit 1
elif [ "${NDM_VERSION%%.*}" -lt 4 ]; then
	# ndm/iflayerchanged.d does not exist in versions below 4.0.0
	echo "NDM version $NDM_VERSION is less than 4.0.0" >&2
	exit 1
fi

echo Installing packages...
opkg update && opkg install coreutils-sort cron curl dnsmasq git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy

delete_service "$ZAPRET_BASE" "$ZAPRET_SCRIPT"
echo Installing zapret...
if ! curl --fail -L "$ZAPRET_URL" | tar -xz -C /opt/; then
	echo "Failed to download zapret archive" >&2
	exit 1
fi
mv "/opt/zapret-$ZAPRET_VERSION/" "$ZAPRET_BASE"

delete_service "$DNSMASQ_ROUTING_BASE" "$DNSMASQ_ROUTING_SCRIPT"
echo Installing Keenetic Bypass...
rm_dir "$KEENETIC_BYPASS_TMP_DIR"
if ! git clone --depth=1 "$KEENETIC_BYPASS_URL" "$KEENETIC_BYPASS_TMP_DIR"; then
	echo "Failed to clone Keenetic Bypass repository" >&2
	exit 1
fi
cp -r "$KEENETIC_BYPASS_TMP_DIR/opt/." /opt/

echo Configuring zapret...
"$ZAPRET_INSTALL_BIN"
"$ZAPRET_GET_CONFIG"

echo Changing the settings...
if ! get_zapret_config_iface_wan; then
	echo "Failed to retrieve WAN interface" >&2
	exit 1
elif ! get_dnsmasq_config_server; then
	echo "Failed to retrieve DNS server" >&2
	exit 1
elif ! select_dnsmasq_routing_interface; then
	echo "Failed to retrieve routing interface" >&2
	exit 1
fi

replace_config_value "$ZAPRET_CONFIG" "IFACE_WAN" "$ZAPRET_CONFIG_IFACE_WAN"
replace_config_value "$DNSMASQ_CONFIG" "server" "$DNSMASQ_CONFIG_SERVER"
replace_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE" "$DNSMASQ_ROUTING_CONFIG_INTERFACE"
replace_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE_SUBNET" "$DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET"

if ask_yes_no "y" "Run ipset dnsmasq routing auto-save daily?"; then
	add_cron_job "0 0 * * * $DNSMASQ_ROUTING_SCRIPT save"
fi
if ask_yes_no "y" "Run zapret domain list update daily?"; then
	add_cron_job "0 0 * * * $ZAPRET_GET_CONFIG"
fi

echo Running zapret...
"$ZAPRET_SCRIPT" start
echo Running dnsmasq routing...
"$DNSMASQ_ROUTING_SCRIPT" start

rm_dir "$KEENETIC_BYPASS_TMP_DIR"

echo Components have been successfully installed. For further configuration please refer to README.md file!
