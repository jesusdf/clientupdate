#!/bin/bash
echo -n "CPU Schedulers: "
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors

if [ "$1" != "" ]; then
	echo -n "Disk schedulers ($1): "
	cat /sys/block/$1/queue/scheduler
fi;
