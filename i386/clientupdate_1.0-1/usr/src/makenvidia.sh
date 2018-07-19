#!/bin/bash

TTY=/dev/tty2

clear > ${TTY}

# Cambiamos al terminal 2
chvt 2

cd "$(dirname "$0")"

if [ "$(uname -m)" == "x86_64" ]; then
    NVIDIAURL=https://www.nvidia.com/object/linux-amd64-display-archive.html
else
    NVIDIAURL=https://www.nvidia.com/object/linux-display-archive.html
fi

#if [ -d /usr/src/linux-headers-$(uname -r) ]; then
#    echo "Adjusting source path to use kernel headers..." > ${TTY}
#    if [ -d /lib/modules/$(uname -r)/build ]; then
#        rm -f /lib/modules/$(uname -r)/build
#    fi
#    if [ -d /lib/modules/$(uname -r)/source ]; then
#        rm -f /lib/modules/$(uname -r)/source
#    fi
#    ln -s /usr/src/linux-headers-$(uname -r) /lib/modules/$(uname -r)/build
#    ln -s /usr/src/linux-headers-$(uname -r) /lib/modules/$(uname -r)/source
#fi

# Old URL: http://www.nvidia.com/object/unix.html

echo "Looking for the latest driver..." > ${TTY}
wget -q -O /tmp/tmpnvidia $NVIDIAURL > ${TTY}
DOWNLOADURL=https://$(cat /tmp/tmpnvidia | grep driverResults | head -n 1 | cut -d/ -f 3- | cut -d\" -f 1)
rm /tmp/tmpnvidia
wget -q -O /tmp/tmpnvidia "${DOWNLOADURL}" > ${TTY}
DRIVERURL=https://us.download.nvidia.com$(cat /tmp/tmpnvidia | grep confirmation.php | head -n 1 | cut -d\" -f 2 | cut -d\= -f 2 | cut -d\& -f 1)

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
