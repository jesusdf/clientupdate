#!/bin/bash

NVME_WRITTEN=$(LANG=C /usr/sbin/smartctl -a /dev/$1 | grep "Data Units Written" | cut -d: -f2- | xargs | cut -d[ -f2 | cut -d] -f 1)

if [ "$NVME_WRITTEN" != "" ]; then
    echo "$NVME_WRITTEN"
    exit 0
fi

SECTOR_SIZE=$(LANG=C /usr/sbin/smartctl -i /dev/$1 | grep "Sector Size" | xargs | cut -d\  -f3 ) 
SECTORS_WRITTEN=$(LANG=C /usr/sbin/smartctl -A /dev/$1 | grep LBAs | xargs | rev | cut -d\  -f1 | rev)

if [ "$SECTORS_WRITTEN" == "" ]; then
    echo "$1 is not an SSD."
    exit 0
fi

MBW=$(( $SECTOR_SIZE * $SECTORS_WRITTEN / 1024 / 1024 ))
GBW=$(( $MBW / 1024 ))
TBW=$(( $GBW / 1024 ))

if [ "$TBW" == "0" ]; then
    if [ "$GBW" == "0" ]; then
        echo "$MBW MBW"
    else
        echo "$GBW GBW / $MBW MBW"
    fi
else
    echo "$TBW TBW / $GBW GBW"
fi
