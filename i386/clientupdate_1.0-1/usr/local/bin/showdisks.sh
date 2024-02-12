#!/bin/bash
DISKS=$( cd /dev && ls {sd?,nvme?} )
for DISK in $DISKS; do
	smartctl -i /dev/$DISK 2>&1 | grep erial | sed "s/Serial Number/$DISK/g" | sed "s/Serial number/$DISK/g" | xargs
done
hddtemp /dev/sd? 2>/dev/null

