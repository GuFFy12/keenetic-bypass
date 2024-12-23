#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

ZAPRET_VERSION="v69.8"

ZAPRET_SCRIPT="/opt/zapret/init.d/sysv/zapret_keenetic.sh"
DNSMASQ_ROUTING_SCRIPT="/opt/dnsmasq_routing/dnsmasq_routing.sh"

replace_config_value() {
    sed -i "s|^$2=.*|$2=$3|" "$1"
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
rm -r /opt/zapret
curl -L "https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz" | tar -xz -C /opt/
mv "/opt/zapret-$ZAPRET_VERSION/" /opt/zapret/

[ -f "$DNSMASQ_ROUTING_SCRIPT" ] && "$DNSMASQ_ROUTING_SCRIPT" stop
rm -r /opt/tmp/keenetic-bypass/
git clone --depth=1 https://github.com/GuFFy12/keenetic-bypass.git /opt/tmp/keenetic-bypass/
find /opt/tmp/keenetic-bypass/opt/ -type f | while read -r file; do
    dest="/opt/${file#/opt/tmp/keenetic-bypass/opt/}"

    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
done

/opt/zapret/install_bin.sh
/opt/zapret/ipset/get_config.sh

replace_config_value "/opt/zapret/config" "IFACE_WAN" "$(ip route | grep -w ^default | awk '{print $5}')"
replace_config_value "/opt/dnsmasq_routing/dnsmasq.conf" "server" "127.0.0.1#$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"
replace_config_value "/opt/dnsmasq_routing/dnsmasq_routing.conf" "INTERFACE" "t2s0"
replace_config_value "/opt/dnsmasq_routing/dnsmasq_routing.conf" "INTERFACE_SUBNET" "172.20.12.1/32"

/opt/zapret/init.d/sysv/zapret_keenetic.sh restart
/opt/dnsmasq_routing/dnsmasq_routing.sh restart
