#!/bin/bash
if [ "$1" == "" ]; then
    echo "Usage: $0 sda [scheduler]"
    exit -1
fi
echo "$1 supported ioschedulers:"
cat /sys/block/$1/queue/scheduler
if [ "$2" != "" ]; then
    echo "Setting $2 ioscheduler on $1..."
    echo $2 > /sys/block/$1/queue/scheduler
    cat /sys/block/$1/queue/scheduler
fi
