#!/bin/bash
# Enable-IDA
# YMMV
# disable EIST
# https://askubuntu.com/questions/619875/disabling-intel-turbo-boost-in-ubuntu
wrmsr -p0 0x1a0 0x4000850089
wrmsr -p1 0x1a0 0x4000850089
# enable Dual-IDA
# http://forum.notebookreview.com/threads/how-to-enable-intel-dynamic-acceleration-ida-on-both-cores-of-a-core-2-duo.477704/page-48
wrmsr 0x1a0 0x1364862489
echo 0 > /sys/devices/system/cpu/cpu1/online
rdmsr -p0 0x198
wrmsr 0x199 0xa24
wrmsr 0x1a0 0x5364872489
wrmsr 0x1a0 0x1364862489
rdmsr -p0 0x198
echo 1 > /sys/devices/system/cpu/cpu1/online
rdmsr -p0 0x198
rdmsr -p1 0x198
