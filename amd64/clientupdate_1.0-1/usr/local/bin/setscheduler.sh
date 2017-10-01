#!/bin/bash
CPUS=$(cat /proc/stat|sed -ne 's/^cpu\([[:digit:]]\+\).*/\1/p')
for cpu in $CPUS ; do
      /usr/bin/cpufreq-set --cpu $cpu -g $1
done

