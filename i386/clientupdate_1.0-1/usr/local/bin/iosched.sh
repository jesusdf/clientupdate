#!/bin/bash
if [ "$1" == "" ]; then
    echo "Usage: $0 sda [scheduler]"
    exit -1
fi
DISK=${1/\/dev\//}
IOSCHED=$(cat /sys/block/$DISK/queue/scheduler)
NEWSCHED=$2
ISHDD=$(cat /sys/block/$DISK/queue/rotational)
MQENABLED=0
if [ -d /sys/block/$DISK/mq ]; then
    MQENABLED=1
fi
echo "$DISK supported ioschedulers:"
echo $IOSCHED
if [ "$NEWSCHED" == "" ]; then
    if [ "$ISHDD" == "1" ]; then
        if [ "$MQENABLED" == "1" ]; then
	    NEWSCHED=none
	else
            NEWSCHED=deadline
        fi
    else
        if [ "$MQENABLED" == "1" ]; then
            NEWSCHED=mq-deadline
        else
            NEWSCHED=noop
        fi
    fi
fi
if [[ $IOSCHED = *"$NEWSCHED"* ]]; then
    echo "Setting $NEWSCHED ioscheduler on $DISK..."
    echo $NEWSCHED > /sys/block/$DISK/queue/scheduler
    cat /sys/block/$DISK/queue/scheduler
else
    echo "Unsupported ioscheduler $NEWSCHED, no change was made."
fi
