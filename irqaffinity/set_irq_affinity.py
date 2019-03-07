#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
	usage: set_dev_cpu_affinity.py <dev> <cpulist> [mode]
"""

import os
import sys
import re
import collections

def get_irq_list(dev):
	irq_list = []
	irq_file = open("/proc/interrupts")
	for line in irq_file:
		elems = line.strip().split()
		irq_num = elems[0]
		irq_desc = elems[-1]
		if not re.search(dev, irq_desc):
			continue
		try:
			irq_num = int(irq_num[:-1])
		except:
			continue

		irq_list.append(irq_num)
		#print("dev:%s: irq:%d" % (irq_desc, irq_num))

	return irq_list

def write_irq_mask(irq, mask):
	if mask.startswith('0x') or mask.startswith('0X'):
		mask = mask[2:]
	mask = mask.zfill(16)
	cmd_str = "echo " + mask[0:8] + "," + mask[8:16] + " > " + "/proc/irq/" + str(irq) + "/smp_affinity"
	print("cmdstr:%s" % (cmd_str))
	os.system(cmd_str)


def set_dev_cpu_affinity(irq_list, cpu_list, mode):
	if mode:
		for irq in irq_list:
			cpu_mask = 0
			for cpu in cpu_list:
				cpu_mask |= (0x01 << cpu)
			cpu_mask_str = str(hex(cpu_mask))
			write_irq_mask(irq, cpu_mask_str)
		return

	cpu_num = len(cpu_list)
	cpu_index = 0
	for irq in irq_list:
		cpu_mask = 0x01 << cpu_list[cpu_index]
		cpu_mask_str = str(hex(cpu_mask))
		write_irq_mask(irq, cpu_mask_str)

		cpu_index += 1
		if cpu_index >= cpu_num:
			cpu_index = 0
		
	return

def get_cpu_sub_list(substr):
	sublist = []
	if re.findall('-', substr) and re.findall(':', substr):
		print("invalid substr:%s" % (substr))
		return sublist

	if substr.isdigit():
		sublist.append(int(substr))
	elif (':' in substr):
		ranglist=substr.split(':')
		start = int(ranglist[0])
		end = start + int(ranglist[1])
		sublist += range(start, end)
	else:
		ranglist=substr.split('-')
		start = int(ranglist[0])
		end = int(ranglist[1])
		sublist += range(start, end)
		sublist.append(end)

	return sublist

def get_cpu_list(cpustr):
	tmp_list = []

	if re.findall("[^0-9,:-]", cpustr):
		print("cpustr invalid")
		return tmp_list

	strlist=cpustr.split(',')
	if len(strlist) == 0:
		print("strlist is empty")
		return tmp_list
	for itemstr in strlist:
		if len(itemstr) == 0:
			continue
		tmp_list += get_cpu_sub_list(itemstr)

	cpu_list = []
	cpu_set = set()

	for cpu in tmp_list:
		if cpu not in cpu_set:
			cpu_set.add(cpu)
			cpu_list.append(cpu)
		
	return cpu_list

if __name__ == "__main__":
	if len(sys.argv) < 3:
		print("usage set_dev_cpu_affinity.py <dev> <cpulist> [mode]")
		exit(-1)

	dev = sys.argv[1]
	cpulist_str = sys.argv[2]
	unity_mode = False
	if len(sys.argv) >= 4 and sys.argv[3] == "unity":
		unity_mode = True

	print("dev:%s,cpulist:%s,mode:%d\n" % (dev, cpulist_str, unity_mode))
		
	cpulist = get_cpu_list(cpulist_str)
	if len(cpulist) == 0:
		print("cpu list is empty")
		exit(-1)

	irqlist = get_irq_list(dev)
	if len(irqlist) == 0:
		print("irq list is empty")
		exit(-1)

	print "cpulist: " + str(cpulist)
	print "irqlist: " + str(irqlist)

	set_dev_cpu_affinity(irqlist, cpulist, unity_mode)

	exit(0)
