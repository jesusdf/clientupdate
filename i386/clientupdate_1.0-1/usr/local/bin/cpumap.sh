#!/bin/bash
egrep 'processor|core id|physical id' /proc/cpuinfo | cut -d : -f 2 | paste - - -  | awk '{print "CPU"$1"\tsocket "$2" core "$3}'
