#!/bin/bash
if $(which apt-get > /dev/null 2>&1); then
	apt-get install -y numactl gcc pciutils
	apt-get install -y bridge-utils procinfo
fi

if $(which yum >/dev/null 2>&1); then
	yum install -y numactl gcc pciutils
fi

hwinfo_test()
{
	echo
	echo "1. cat /proc/cpuinfo > $LOG_DIR/cpuinfo.txt"
	echo
	cat /proc/cpuinfo > $LOG_DIR/cpuinfo.txt
	echo
	echo "2.cat /proc/meminfo"
	echo
	cat /proc/meminfo
	echo
	echo "3.lscpu"
	echo
	lscpu
	echo
	echo "4.lshw > $LOG_DIR/lshw.txt"
	echo
	lshw > $LOG_DIR/lshw.txt
	echo
	echo "5.fdisk -l"
	echo
	fdisk -l
	echo
	echo "6.df -mP"
	echo
	df -mP
	echo
	echo "7.uname -a"
	echo
	uname -a
	echo
	echo "8.lspci -vvnn > $LOG_DIR/lspci.txt"
	echo
	lspci -vvnn > $LOG_DIR/lspci.txt
	echo
	echo "9.gcc --version"
	echo
	gcc --version
	echo
	echo "10.ld --version"
	echo
	ld --version
	echo
	echo "11.hostname"
	echo
	hostname
	echo
	echo "12.ifconfig -a"
	echo
	ifconfig -a
	echo
	echo "13.brctl show"
	echo
	brctl show
	echo
	echo "14. cat /proc/cmdline"
	echo
	cat /proc/cmdline
	echo
	echo "15. dmesg > $LOG_DIR/dmesg.txt"
	echo
	dmesg > $LOG_DIR/dmesg.txt
	echo
	echo "17. cat /var/log/syslog > $LOG_DIR/syslog"
	echo
	cat /var/log/syslog > $LOG_DIR/syslog
	echo
	echo "18. dmidecode"
	echo
	dmidecode
	echo
	echo "19. ps -ef"
	echo
	ps -ef
	echo
	echo "20. lsdev"
	echo
	lsdev
	echo
	echo "21. lsb_release -a"
	echo
	lsb_release -a
	echo
	echo "22. mount"
	echo
	mount
	echo
	echo "23. cat/etc/fstab"
	echo
	cat /etc/fstab

	echo
	echo "24. free -m |grep 'Mem:' |awk -F : '{print $2}' |awk '{print $1}'"
	echo
	free -m |grep 'Mem:' |awk -F : '{print $2}' |awk '{print $1}'
	echo
	echo "25. zcat /proc/config.gz > $LOG_DIR/kernel.config"
	echo
	zcat /proc/config.gz > $LOG_DIR/kernel.config
	echo
	echo "26.cat /proc/cmdline"
	echo
	cat /proc/cmdline

	echo
	echo "numactl -H"
	echo
	numactl -H

	echo
	echo "lsblk"
	echo
	lsblk
}

LOG_DIR=`pwd`/hwinfo-`date +%m%d%H%M`
mkdir -p $LOG_DIR

hwinfo_test > $LOG_DIR/hwinfo.txt 2>&1
