#!/bin/sh

SCRIPT="$(readlink -f "$0")"
ZAPRET_SCRIPT="$(dirname "$SCRIPT")/zapret"
KERNEL_VERSION="$(uname -r)"

load_kernel_module() {
	if ! lsmod | grep -q "$1" && ! insmod "/lib/modules/$KERNEL_VERSION/$1.ko"; then
		exit 1
	fi
}

do_start() {
	# Kernel modules sometimes do not load automatically
	load_kernel_module xt_multiport
	load_kernel_module xt_connbytes
	load_kernel_module xt_NFQUEUE

	# --dpi-desync-fooling=badsum fix
	sysctl -w net.netfilter.nf_conntrack_checksum=0
}

do_stop() {
	sysctl -w net.netfilter.nf_conntrack_checksum=1
}

case "$1" in
start)
	do_start
	ZAPRET_SCRIPT start
	;;

stop)
	ZAPRET_SCRIPT stop
	do_stop
	;;

restart)
	do_start
	ZAPRET_SCRIPT start
	ZAPRET_SCRIPT stop
	do_stop
	;;

*)
	echo "Usage: $SCRIPT {start|stop|restart}" >&2
	exit 1
	;;
esac

exit 0
