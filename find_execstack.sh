#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <target>"
    exit 1;
fi

kav_pid=`pidof $1`
for so in `cat /proc/$kav_pid/task/*/maps | awk '/.so$/ {print $6}' | sort | uniq`; do
    stack_perms=`readelf -Wl $so | awk '/GNU_STACK/ {print $7}'`
    if [ -z "$stack_perms" ]; then
        echo "$so doesn't have PT_GNU_STACK"
    elif [ "$stack_perms" != "RW" ]; then
        echo "$so has unexpected permissions: $stack_perms"
    fi
done
