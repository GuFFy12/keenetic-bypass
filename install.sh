#!/bin/sh

ZAPRET_VERSION="v69.8"

TMP_DIR="/opt/tmp/keenetic-bypass"
ZAPRET_BASE="/opt/zapret"
DNSMASQ_ROUTING_BASE="/opt/dnsmasq_routing"
ZAPRET_SCRIPT="$ZAPRET_BASE/init.d/sysv/zapret_keenetic.sh"
DNSMASQ_ROUTING_SCRIPT="$DNSMASQ_ROUTING_BASE/dnsmasq_routing.sh"

replace_config_value() {
	sed -i "s|^$2=.*|$2=$3|" "$1"
}

rm_dir() {
	[ -d "$1" ] && rm -r "$1"
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
	printf "%s (default: %s) (Y/N): " "$2" "${1:-N}"
	read -r A

	[ -z "$A" ] && A="${1:-N}"

	case "$A" in
	[yY1]) return 0 ;;
	[nN0]) return 1 ;;
	*) return 1 ;;
	esac
}

if ! command -v ndmc >/dev/null; then
	echo "ndmc not found" >&2
	exit 1
fi

if ! command -v opkg >/dev/null; then
	echo "opkg not found" >&2
	exit 1
fi

echo Installing packages...
opkg update && opkg install coreutils-sort curl dnsmasq git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy

NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd '0-9.')"

if [ -z "$NDM_VERSION" ]; then
	echo "Invalid or missing version" >&2
	exit 1
fi

# ndm/iflayerchanged.d does not exist in versions below 4.0.0
if [ "${NDM_VERSION%%.*}" -lt 4 ]; then
	echo "Version $NDM_VERSION is less than 4.0.0" >&2
	exit 1
fi

echo "ndm version: $NDM_VERSION"

echo Installing zapret...
[ -f "$ZAPRET_SCRIPT" ] && "$ZAPRET_SCRIPT" stop
rm_dir "$ZAPRET_BASE"
curl -L "https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz" | tar -xz -C /opt/ | tar -xz -C /opt/ || {
	echo "Failed to download or extract zapret-$ZAPRET_VERSION.tar.gz" >&2
	exit 1
}
mv "/opt/zapret-$ZAPRET_VERSION/" "$ZAPRET_BASE"

echo Installing Keenetic Bypass...
[ -f "$DNSMASQ_ROUTING_SCRIPT" ] && "$DNSMASQ_ROUTING_SCRIPT" stop
rm_dir "$DNSMASQ_ROUTING_BASE"
rm_dir "$TMP_DIR"
git clone --depth=1 https://github.com/GuFFy12/keenetic-bypass.git "$TMP_DIR" || {
	echo "Failed to clone the keenetic-bypass repository" >&2
	exit 1
}
find "$TMP_DIR/opt/" -type f | while read -r file; do
	dest="/opt/${file#"$TMP_DIR/opt/"}"

	mkdir -p "$(dirname "$dest")"
	cp "$file" "$dest"
done

echo Configuring zapret...
"$ZAPRET_BASE/install_bin.sh"
"$ZAPRET_BASE/ipset/get_config.sh"

echo Changing the settings...
replace_config_value "$ZAPRET_BASE/config" "IFACE_WAN" "$(ip route | grep -w ^default | awk '{print $5}')"
replace_config_value "$DNSMASQ_ROUTING_BASE/dnsmasq.conf" "server" "127.0.0.1#$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"
replace_config_value "$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf" "INTERFACE" "t2s0"
replace_config_value "$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf" "INTERFACE_SUBNET" "172.20.12.1/32"

ask_yes_no "y" "Do you want to run the ipset dnsmasq routing auto-save daily?"
if [ $? -eq 0 ]; then
	add_cron_job "0 0 * * * /opt/dnsmasq_routing/dnsmasq_routing.sh save"
fi

ask_yes_no "y" "Do you want to run the zapret domain list update daily?"
if [ $? -eq 0 ]; then
	add_cron_job "0 0 * * * /opt/zapret/ipset/get_config.sh"
fi

echo Running zapret...
"$ZAPRET_SCRIPT" start
echo Running dnsmasq_routing...
"$DNSMASQ_ROUTING_SCRIPT" start

rm_dir "$TMP_DIR"

echo Components have been successfully installed. For further configuration please refer to README.md file!
