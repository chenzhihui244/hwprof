#!/bin/bash

cpu_lo=0
cpu_up=31

get_dev_irq_list() {
	local dev=$1
	while read line; do
		local irq=`echo $line | grep "$dev" | cut -d: -f1 | sed "s/ //g"`
		if [ -z $irq ]; then
			continue
		fi
		echo "$irq"
	done < /proc/interrupts
}

get_irq_list_affinity() {
	local irq_list=$*
	for irq in $irq_list; do
		echo -n "irq[$irq] - 0x"
		cat /proc/irq/$irq/smp_affinity
	done
}

set_irq_list_affinity() {
	local irq_list=$*
	local cpu=$cpu_lo
	for irq in $irq_list; do
		local pos=$(( 1<<cpu ))
		local mask=`printf "%x" $pos`
		local affinity=`echo $mask | sed -e ':a' -e 's/\(.*[0-9]\)\([0-9]\{8\}\)/\1,\2/;ta'`
		echo "irq[$irq], cpu[$cpu], affinity[$affinity]"
		echo "$affinity" > /proc/irq/$irq/smp_affinity

		let cpu=cpu+1
		if (( cpu > cpu_up )); then
			let cpu=cpu_lo
		fi
	done
}

set_eth_irq_affinity() {
	local dev=$1
	for suffix in rx tx; do
		irq_list=`get_dev_irq_list "$dev-$suffix"`
		set_irq_list_affinity "$irq_list"
	done
}

get_eth_irq_affinity() {
	local dev=$1
	for suffix in rx tx; do
		irq_list=`get_dev_irq_list "$dev-$suffix"`
		get_irq_list_affinity "$irq_list"
	done
}

set_dev_irq_affinity() {
	local dev=$1
	irq_list=`get_dev_irq_list "$dev"`
	set_irq_list_affinity "$irq_list"
}

get_dev_irq_affinity() {
	local dev=$1
	irq_list=`get_dev_irq_list "$dev"`
	get_irq_list_affinity "$irq_list"
}

if [ $1 = "-f" ]; then
	shift
	$*
fi
