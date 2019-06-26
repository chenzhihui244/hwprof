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
	lscpu > $LOG_DIR/lscpu.txt
	echo
	echo "4.lshw > $LOG_DIR/lshw.txt"
	echo
	lshw > $LOG_DIR/lshw.txt
	echo
	echo "5.fdisk -l"
	echo
	fdisk -l > $LOG_DIR/fdisk-l.txt
	echo
	echo "6.df -mP"
	echo
	df -mP > $LOG_DIR/df-mp.txt
	echo
	echo "7.uname -a"
	echo
	uname -a > $LOG_DIR/uname-a.txt
	echo
	echo "8.lspci -vvnn > $LOG_DIR/lspci.txt"
	echo
	lspci -vvnn > $LOG_DIR/lspci-vvnn.txt
	lspci -tv > $LOG_DIR/lspci-tv.txt
	echo
	echo "9.gcc -v"
	echo
	gcc -v > $LOG_DIR/gcc-v.txt
	echo
	echo "10.ld --version"
	echo
	ld --version > $LOG_DIR/ld-v.txt
	echo
	echo "11.hostname"
	echo
	hostname > $LOG_DIR/hostname.txt
	echo
	echo "12.ifconfig -a"
	echo
	ifconfig -a > $LOG_DIR/ifconfig-a.txt
	echo
	echo "13.brctl show"
	echo
	brctl show > $LOG_DIR/brctl-show.txt
	echo
	echo "14. cat /proc/cmdline"
	echo
	cat /proc/cmdline > $LOG_DIR/cmdline.txt
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
	dmidecode > $LOG_DIR/dmidecode.txt
	echo
	echo "19. ps -ef"
	echo
	ps -eLf >$LOG_DIR/ps-elf.txt
	echo
	echo "20. lsdev"
	echo
	lsdev > $LOG_DIR/lsdev.txt
	echo
	echo "21. lsb_release -a"
	echo
	lsb_release -a > $LOG_DIR/lsb_release.txt
	echo
	echo "22. mount"
	echo
	mount > $LOG_DIR/mount.txt
	echo
	echo "23. cat/etc/fstab"
	echo
	cat /etc/fstab > $LOG_DIR/fstab.txt

	echo
	echo "24. free -m |grep 'Mem:' |awk -F : '{print $2}' |awk '{print $1}'"
	echo
	free -m |grep 'Mem:' |awk -F : '{print $2}' |awk '{print $1}' > $LOG_DIR/free.txt
	echo
	echo "25. zcat /proc/config.gz > $LOG_DIR/kernel.config"
	echo
	zcat /proc/config.gz > $LOG_DIR/kernel.config
	cp /boot/config-`uname -r` $LOG_DIR
	echo
	echo "26.cat /etc/*release*"
	echo
	cat /etc/*release* > $LOG_DIR/release.txt
	echo
	echo "27.cat /etc/*version*"
	echo
	cat /etc/*version* > $LOG_DIR/version.txt

	echo
	echo "numactl -H"
	echo
	numactl -H > $LOG_DIR/numactl-h.txt

	echo
	echo "lsblk"
	echo
	lsblk > $LOG_DIR/lsblk.txt

	echo
	echo "transparent huge page setting"
	echo
	echo "/sys/kernel/mm/transparent_hugepage/enabled" > $LOG_DIR/transparent_hugepage.txt
	cat /sys/kernel/mm/transparent_hugepage/enabled >> $LOG_DIR/transparent_hugepage.txt
	echo "/sys/kernel/mm/transparent_hugepage/defrag" >> $LOG_DIR/transparent_hugepage.txt
	cat /sys/kernel/mm/transparent_hugepage/defrag >> $LOG_DIR/transparent_hugepage.txt

	echo
	echo "ulimt config"
	echo
	ulimit -a > $LOG_DIR/ulimit.txt

	echo
	echo "schedstat info"
	echo
    cat /proc/schedstat > $LOG_DIR/schedstat
}

LOG_DIR=`pwd`/hwinfo-`date +%Y%m%d%H%M`
mkdir -p $LOG_DIR

hwinfo_test > $LOG_DIR/hwinfo.txt 2>&1
