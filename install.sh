#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

RELEASE_TAG=v1.0.0

ZAPRET_BASE="${ZAPRET_BASE:-/opt/zapret}"
ZAPRET_SCRIPT="${ZAPRET_SCRIPT:-"$ZAPRET_BASE/init.d/sysv/zapret_keenetic.sh"}"
ZAPRET_CONFIG="${ZAPRET_CONFIG:-"$ZAPRET_BASE/config"}"
ZAPRET_INSTALL_BIN="${ZAPRET_INSTALL_BIN:-"$ZAPRET_BASE/install_bin.sh"}"
ZAPRET_GET_CONFIG="${ZAPRET_GET_CONFIG:-"$ZAPRET_BASE/ipset/get_config.sh"}"

ask_yes_no() {
	while true; do
		echo "$1 (Y/N): "
		read -r answer

		case "$answer" in
		[yY1]) return 0 ;;
		[nN0]) return 1 ;;
		*) echo Invalid choice ;;
		esac
	done
}

set_config_value() {
	sed -i "s|^$2=.*|$2=$3|" "$1"
}

add_cron_job() {
	if ! crontab -l 2>/dev/null | grep -Fq "$2"; then
		(
			crontab -l 2>/dev/null
			echo "$1 $2"
		) | crontab -
	fi
}

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
opkg update && opkg install coreutils-sort cron curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy

echo Installing Keenetic Zapret...
delete_service "$ZAPRET_BASE" "$ZAPRET_SCRIPT"
if [ -n "$(readlink -f "$0")" ]; then
	cp -r opt/* /opt/
else
	TMP_DIR=$(mktemp -d)
	RELEASE_FILE="keenetic-zapret-$RELEASE_TAG.tar.gz"

	curl -f -L -o "$TMP_DIR/$RELEASE_FILE" "https://github.com/GuFFy12/keenetic-zapret/releases/download/$RELEASE_TAG/$RELEASE_FILE"
	tar -xvzf "$TMP_DIR/$RELEASE_FILE" -C "$TMP_DIR" >/dev/null
	cp -r "$TMP_DIR/opt/"* /opt/
	rm -rf "$TMP_DIR"
fi

echo Changing the settings...
if ! get_zapret_config_iface_wan; then
	echo Failed to retrieve WAN interface for zapret >&2
	exit 1
fi

replace_config_value "$ZAPRET_CONFIG" "IFACE_WAN" "$ZAPRET_CONFIG_IFACE_WAN"

echo Configuring zapret...
"$ZAPRET_INSTALL_BIN"

if ask_yes_no "Create cron job to auto update zapret ipset list?"; then
	add_cron_job "0 0 * * *" "$ZAPRET_GET_CONFIG"
fi

echo Running zapret...
"$ZAPRET_SCRIPT" start
echo Downloading latest ipset domains list...
"$ZAPRET_GET_CONFIG"

echo Zapret have been successfully installed. For further configuration please refer to README.md file!
