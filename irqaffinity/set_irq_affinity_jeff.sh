#!/bin/sh
# setting up irq affinity according to /proc/interrupts
# 2008-11-25 Robert Olsson
# 2009-02-19 updated by Jesse Brandeburg
#
# > Dave Miller:
# (To get consistent naming in /proc/interrups)
# I would suggest that people use something like:
#       char buf[IFNAMSIZ+6];
#
#       sprintf(buf, "%s-%s-%d",
#               netdev->name,
#               (RX_INTERRUPT ? "rx" : "tx"),
#               queue->index);
#
#  Assuming a device with two RX and TX queues.
#  This script will assign:
#
#       eth0-rx-0  CPU0
#       eth0-rx-1  CPU1
#       eth0-tx-0  CPU0
#       eth0-tx-1  CPU1
#

if [ "$1" = "" ] ; then
        echo "Description:"
        echo "    This script attempts to bind each queue of a multi-queue NIC"
        echo "    to the same numbered core, ie tx0|rx0 --> cpu0, tx1|rx1 --> cpu1"
        echo "usage:"
        echo "    $0 eth0 [eth1 eth2 eth3]"
fi

# check for irqbalance running
IRQBALANCE_ON=`ps ax | grep -v grep | grep -q irqbalance; echo $?`
if [ "$IRQBALANCE_ON" == "0" ]; then
        echo " WARNING: irqbalance is running and will"
        echo "          likely override this script's affinitization."
        echo "          Please stop the irqbalance service and/or execute"
        echo "          'killall irqbalance'"
fi

#
# Set up the desired devices.
#
set_affinity()
{
	local DEV=$1
	local DIR=$2
	local VEC=$3
	local IRQ=$4
	local POS=$[$VEC%$CORENUM]

	MASK=$((1<<$POS))
	printf "DEV:%s DIR:%s VEC:%d POS:%d MASK:0x%X IRQ:%d\n" $DEV $DIR $VEC $POS $MASK $IRQ
	TMP=`printf "%X" $MASK`
	echo $TMP|sed -e ':a' -e 's/\(.*[0-9]\)\([0-9]\{8\}\)/\1,\2/;ta' > /proc/irq/$IRQ/smp_affinity
}

set_affinity_dir()
{
	local DEV=$1
	local DIR=$2

	MAX=`grep -i $DEV-$DIR /proc/interrupts | wc -l`
	if [ "$MAX" == "0" ] ; then
		MAX=`egrep -i "$DEV:.*$DIR" /proc/interrupts | wc -l`
	fi

	if [ "$MAX" == "0" ] ; then
		return 1
	fi

	(( MAX-- ))
	for VEC in `seq 0 1 $MAX`
	do
		IRQ=`cat /proc/interrupts | grep -i $DEV-$DIR$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
		if [ -n  "$IRQ" ]; then
			set_affinity $DEV $DIR $VEC $IRQ
			continue
		fi

		IRQ=`cat /proc/interrupts | grep -i $DEV-$DIR-$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
		if [ -n  "$IRQ" ]; then
			set_affinity $DEV $DIR $VEC $IRQ
			continue
		fi

		IRQ=`cat /proc/interrupts | egrep -i $DEV:v$VEC-$DIR"$"  | cut  -d:  -f1 | sed "s/ //g"`
		if [ -n  "$IRQ" ]; then
			set_affinity $DEV $DIR $VEC $IRQ
			continue
		fi
	done
}

DEV=${1}
CORENUM=${2:-`nproc`}

set_affinity_dir $DEV TxRx
if [ $? == 0 ]; then
	exit
fi

set_affinity_dir $DEV Tx
set_affinity_dir $DEV Rx
