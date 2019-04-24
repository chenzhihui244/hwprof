#!/bin/bash

if (( $# < 1 )); then
	echo "usage: $0 <dev> [core num] [start core]"
	exit 1
fi

interrupt_file=/proc/interrupts
device=$1
core_total=`nproc`
core_num=${2-${core_total}}
if (( core_num > core_total )); then
	core_num = core_total
fi
start_core=${3-0}

dump_irq_affinity() {
	local dev=$1

	while read line; do
		echo $line | grep -q $dev || continue

		local irq_num=`echo $line | awk '($NF ~ DEV) {print $1}' DEV=$dev`
		local irq_name=`echo $line | awk '{print $NF}'`
		irq_num=`echo $irq_num | cut -d: -f1`
		affinity_file="/proc/irq/$irq_num/smp_affinity"
		echo -n "irq_name:$irq_name irq_num:$irq_num affinity:"
		cat $affinity_file
	done < $interrupt_file
}

set_irq_affinity() {
	local dev=$1
	local core_num=${2}
	local start_core=${3}
	local end_core=0
	local core_pos=0

	let "end_core=start_core+core_num"
	let "core_pos=start_core"

	echo "dev:$dev total:$core_total num:$core_num start:$start_core end_core:$end_core core_pos:$core_pos"

	while read line; do
		echo $line | grep -q $dev || continue

		local irq_num=`echo $line | awk '($NF ~ DEV) {print $1}' DEV=$dev`
		local irq_name=`echo $line | awk '{print $NF}'`
		irq_num=`echo $irq_num | cut -d: -f1`
		local affinity_file="/proc/irq/$irq_num/smp_affinity"

		local bitmap=$((1<<$core_pos))
		local MASK=`printf "%X" $bitmap`
		echo $MASK | sed -e ':a' -e 's/\(.*[0-9]\)\([0-9]\{8\}\)/\1,\2/;ta' > $affinity_file

		echo -n "irq_name:$irq_name irq_num:$irq_num MASK:$MASK affinity:"
		cat $affinity_file
		let "core_pos=core_pos+1"
		if (( core_pos >= end_core )); then
			let "core_pos=$start_core"
		fi
	done < $interrupt_file
}

dump_irq_affinity $device
#set_irq_affinity $device $core_num $start_core
