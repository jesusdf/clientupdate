#!/bin/bash

TTY=/dev/tty7

clear > ${TTY}

# Cambiamos al terminal 7
chvt 7

cd "$(dirname "$0")"

echo "Looking for the latest driver..." > ${TTY}
wget -q -O /tmp/tmpnvidia http://www.nvidia.com/object/unix.html > ${TTY}
DOWNLOADURL=$(cat /tmp/tmpnvidia | grep driverResults | head -n 1 | cut -d\" -f 2)
rm /tmp/tmpnvidia
wget -q -O /tmp/tmpnvidia "${DOWNLOADURL}" > ${TTY}
DRIVERURL=http://us.download.nvidia.com$(cat /tmp/tmpnvidia | grep confirmation.php | head -n 1 | cut -d\" -f 2 | cut -d\= -f 2 | cut -d\& -f 1)

if [ -f NVIDIA*.run ]; then
    if [ ! -d old ]; then
        mkdir old
    fi
    mv -f NVIDIA*.run old/
fi

echo "Downloading NVIDIA driver from ${DRIVERURL}..." > ${TTY}
wget -q "${DRIVERURL}" > ${TTY}

if [ -f NVIDIA*.run ]; then

    chmod 755 NVIDIA*.run

    #echo "Stopping graphical environment..." > ${TTY}
    #/etc/init.d/lightdm stop 2>/dev/null
    #/etc/init.d/mdm stop 2>/dev/null
    #/etc/init.d/sddm stop 2>/dev/null

   echo "Installing NVIDIA driver, please wait..." > ${TTY}
   ./NVIDIA*.run --accept-license --no-x-check --no-questions --silent || echo "Installation failed." > ${TTY}

   echo "Rebooting..." > ${TTY}
   reboot
   echo "Done." > ${TTY}
else
   echo "Download failed." > ${TTY}
fi

