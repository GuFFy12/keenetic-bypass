#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

ZAPRET_VERSION="v69.8"

TMP_DIR="/opt/tmp/keenetic-bypass"
ZAPRET_BASE="/opt/zapret"
DNSMASQ_ROUTING_BASE="/opt/dnsmasq_routing"
ZAPRET_SCRIPT="$ZAPRET_BASE/init.d/sysv/zapret_keenetic.sh"
DNSMASQ_ROUTING_SCRIPT="$DNSMASQ_ROUTING_BASE/dnsmasq_routing.sh"

replace_config_value() {
    sed -i "s|^$2=.*|$2=$3|" "$1"
}

rm_folder() {
    [ -d "$1" ] && rm -r "$1"
}

if ! command -v ndmc; then
    echo "ndmc not found" >&2
    exit 1
fi

if ! command -v opkg; then
    echo "opkg not found" >&2
    exit 1
fi

opkg update && opkg install coreutils-sort curl dnsmasq git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy

NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd '0-9.')"

if [ -z "$NDM_VERSION" ]; then
    echo "Invalid or missing version" >&2
    exit 1
fi

if [ "${NDM_VERSION%%.*}" -lt 4 ]; then
    echo "Version $NDM_VERSION is less than 4.0.0" >&2
    exit 1
fi

[ -f "$ZAPRET_SCRIPT" ] && "$ZAPRET_SCRIPT" stop
rm_folder "$ZAPRET_BASE"
curl -L "https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz" | tar -xz -C /opt/
mv "/opt/zapret-$ZAPRET_VERSION/" "$ZAPRET_BASE"

[ -f "$DNSMASQ_ROUTING_SCRIPT" ] && "$DNSMASQ_ROUTING_SCRIPT" stop
rm_folder "$DNSMASQ_ROUTING_BASE"
rm_folder "$TMP_DIR"
git clone --depth=1 https://github.com/GuFFy12/keenetic-bypass.git "$TMP_DIR"
find "$TMP_DIR/opt/" -type f | while read -r file; do
    dest="/opt/${file#"$TMP_DIR/opt/"}"

    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
done

"$ZAPRET_BASE/install_bin.sh"
"$ZAPRET_BASE/ipset/get_config.sh"

replace_config_value "/opt/zapret/config" "IFACE_WAN" "$(ip route | grep -w ^default | awk '{print $5}')"
replace_config_value "/opt/dnsmasq_routing/dnsmasq.conf" "server" "127.0.0.1#$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"
replace_config_value "/opt/dnsmasq_routing/dnsmasq_routing.conf" "INTERFACE" "t2s0"
replace_config_value "/opt/dnsmasq_routing/dnsmasq_routing.conf" "INTERFACE_SUBNET" "172.20.12.1/32"

"$ZAPRET_SCRIPT" restart
"$DNSMASQ_ROUTING_SCRIPT" restart
