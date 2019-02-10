#!/bin/bash

modprobe msr

cpulist=$(grep processor /proc/cpuinfo | awk '{print $3}')
# stock es 0d20 a efecto práctico, siendo el máximo 0d2c
payload=0d1d # 2.6 Ghz undervolt
#payload=4e24 # 2.9 Ghz overclock razonable
#payload=0f27 # 3.0 Ghz overclock agresivo

#echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

for i in $cpulist; do
   /usr/sbin/wrmsr -p$i 0x194 0x1$payload #change maximum fid/vid
   /usr/sbin/wrmsr -p$i 0x199 0x$payload #apply new fid/vid
done

rmmod msr
