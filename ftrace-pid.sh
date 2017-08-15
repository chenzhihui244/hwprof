#!/bin/bash

# test to be traced
THREAD_NUM=32
size=128M
bm=rd
TRACE_CMD="./getpid.sh /root/c00365621/lmbench/lmbench-3.0-a9/bin/lmbench/bw_mem -P $THREAD_NUM -N 5 $size $bm"

# pid file to transfer pid of child process
PIDFILE="/tmp/getpid.pid"
rm -rf $PIDFILE

# lauch child process to exec test command
eval $TRACE_CMD > /tmp/result.txt 2>&1 &
sleep 0

# get child's pid
CLD_PID=`cat $PIDFILE`
echo "child pid: $CLD_PID"

# deliver pid to ftrace
PERF_PATH="/root/c00365621/perf-tools/bin/tpoint -s -H -p $CLD_PID sched:sched_switch"
#PERF_PATH="/root/c00365621/perf-tools/bin/kprobe -H -p $CLD_PID p:schedule"
#PERF_PATH="/root/c00365621/perf-tools/bin/kprobe p:do_sys_open"

eval $PERF_PATH
