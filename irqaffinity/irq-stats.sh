#!/bin/sh

irqfile=/proc/interrupts
ncpu=`nproc`
cat $irqfile | awk '{n=ncore+2; irqcount=0; for (i=2;i<n;i++) {irqcount+=$i}; if(irqcount!=0) {print irqcount ":" $69} }' ncore=$ncpu
