#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Not enough parameters, example: $0 /dev/sda MyMasterPassword"
    exit -1
fi
UNFROZEN=$(hdparm -I $1 | grep frozen | grep not | wc -l)
if [ "$UNFROZEN" -eq "0" ]; then
    echo "Hard disk is frozen, the system will be set asleep, after wakeup it will resume setting the master password."
    echo "Press any key..."
    read
    pmi action suspend || systemctl suspend
fi
hdparm --user-master m --security-set-pass $2 $1

