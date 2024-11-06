#!/bin/sh

SCRIPT=$(readlink -f "$0")
ZAPRET_SCRIPT=${ZAPRET_SCRIPT:-/opt/${SCRIPT}}

do_start() {
	# Kernel modules sometimes do not load automatically
	insmod /lib/modules/"$(uname -r)"/xt_multiport.ko 2>/dev/null
	insmod /lib/modules/"$(uname -r)"/xt_connbytes.ko 2>/dev/null
	insmod /lib/modules/"$(uname -r)"/xt_NFQUEUE.ko 2>/dev/null

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
