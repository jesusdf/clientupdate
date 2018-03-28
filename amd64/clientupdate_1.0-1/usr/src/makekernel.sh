#!/bin/bash

cd "$(dirname "$0")"

echo "Installing required packages to build the kernel..."
apt-get update 1>/dev/null 2>&1
apt-get -y install wget gcc build-essential fakeroot tar grep sed libncurses5-dev kernel-package libssl-dev libelf-dev bison flex time 1>/dev/null 2>&1

#DESTARCH=$(cc -### -march=native -x c - 2>&1 | grep -v native | grep march | xargs -n 1 | grep march | cut -d= -f2)
DESTPARAMS=$(gcc -march=native -E -v - </dev/null 2>&1 | grep cc1 | cut -d\  -f9-)
DESTARCH=native

unset MAKEFLAGS

echo "Looking for the latest kernel..."
if [ -f /tmp/tmpkernel ]; then 
    rm /tmp/tmpkernel 
fi
wget -q -O /tmp/tmpkernel https://www.kernel.org

KERNELURL=$(cat /tmp/tmpkernel | grep .tar | head -n 1 | cut -d\" -f 2)
KERNELPACKAGE=${KERNELURL##*/}
KERNELVERSION=${KERNELPACKAGE##*-}
KERNELVERSION="${KERNELVERSION%.*}"
KERNELVERSION="${KERNELVERSION%.*}"
KERNELDIR="${KERNELPACKAGE%.*}"
KERNELDIR="${KERNELDIR%.*}"
KERNELEXT="${KERNELPACKAGE##*.}"
MICONFIG=$(ls -bt miconfig* 2>/dev/null | head -n 1)
if [ ! -f "${MICONFIG}" ]; then
        MICONFIG=$(ls -bt /boot/config-* | head -n 1)
fi

rm -f linux-*.${KERNELEXT}
if [ -d linux ]; then
    echo Cleaning previous compilation...
    rm -rf linux
fi

echo "Downloading kernel ${KERNELVERSION} from ${KERNELURL}..."
wget ${KERNELURL} -q --show-progress -O ${KERNELPACKAGE}

echo "Extracting..."
tar -Jxf ${KERNELPACKAGE}
mv ${KERNELDIR} linux

echo "Restoring configuration from ${MICONFIG}..."
cp ${MICONFIG} linux/.config
cd linux

echo "Tuning makefile..."
sed -ri.bak 's/echo "\+"/#echo "\+"/' scripts/setlocalversion*
sed -ri.bak "s/\-O2/\-O3 \-march\=${DESTARCH} \-mtune\=${DESTARCH} \-pipe/g" Makefile
sed -ri.bak2 "s/\-Os/\-O3 \-march\=${DESTARCH} \-mtune\=${DESTARCH} \-pipe/g" Makefile
touch REPORTING-BUGS

echo "Running menu configuration tool..."
make menuconfig

echo "Making backup of config file: miconfig_${KERNELVERSION} ..."
cp .config /usr/src/miconfig_${KERNELVERSION}

echo "Switching to performance mode..."
# Shutdown fancontrol so the fans get at 100%
/etc/init.d/fancontrol stop
# Set performance governor
CPUS=$(cat /proc/stat|sed -ne 's/^cpu\([[:digit:]]\+\).*/\1/p')
for cpu in $CPUS ; do
        /usr/bin/cpufreq-set --cpu $cpu -g performance
done

echo "Building..."
CONCURRENCY_LEVEL=$(getconf _NPROCESSORS_ONLN) time fakeroot make-kpkg --initrd --revision=${KERNELVERSION} --append-to-version=-devel kernel_image kernel_headers

echo "Restoring normal mode..."
for cpu in $CPUS ; do
        /usr/bin/cpufreq-set --cpu $cpu -g ondemand
done
/etc/init.d/fancontrol start

echo "Done!"
cd ..
ls -la linux*.deb

