#!/bin/sh

if $(which yum >/dev/null 2>&1); then
	yum install -y numactl tcpdump sysstat net-tools
fi

if $(which apt >/dev/null 2>&1); then
	apt install -y numactl tcpdump sysstat net-tools
	apt install -y ethtool
	apt install -y linux-tools-common
	apt install -y vim
fi
