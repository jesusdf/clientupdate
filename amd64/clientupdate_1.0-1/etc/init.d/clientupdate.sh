#!/bin/bash
### BEGIN INIT INFO
# Provides:          clientupdate
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Updates the system
# Description: This script will update the most important system software (from a workstation computer point of view).
### END INIT INFO

LOGONUSER=$(cat /etc/passwd | grep 1000 | cut -d: -f1);
LOG_FILE=/tmp/clientupdate_log;
LASTUPDATE_FILE=/etc/default/clientupdate;
INSTALLNVIDIA=$(cat /proc/cmdline | grep installnvidiadriver | wc -l)
NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)

if [ ! "${INSTALLNVIDIA}" -eq "0" ]; then
    sleep 15 && su ${LOGONUSER} -c "DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal 'Installing latest NVIDIA driver, please wait...'" && sleep 5;
    /usr/src/makenvidia.sh &
    exit 0;
fi

if [ ! -f ${LASTUPDATE_FILE} ]; then
    touch ${LASTUPDATE_FILE};
    echo "First run, launching system update in the background in one minute...";
    (
        sleep 60 && /etc/init.d/clientupdate.sh updatesystem;
    ) 1>/dev/null 2>&1 &
    LASTRUN_SECONDS=0;
else
    LASTRUN_SECONDS=$(stat -c %Y ${LASTUPDATE_FILE} | echo $(expr $(date +%s) - $(cat)));
fi

case "$1" in
start)
    # First we finish anything that was unconfigured by a interrupted system update
    echo -n "Configuring pending software now... ";
    dpkg --configure -a || apt-get -f install 1>/dev/null 2>&1;
    echo "done.";
    echo -n "Updating clock in the background... ";
    /etc/init.d/clientupdate.sh time;
    echo "done.";
    echo -n "Launching selfupdate in the background... ";
    /etc/init.d/clientupdate.sh selfupdate;
    echo "done.";
    echo -n "Verifying system configuration in the background... ";
    /etc/init.d/clientupdate.sh config;
    echo "done.";
    echo -n "Checking if system update is needed... ";
    # 2 days of delay between updates
    if [ $LASTRUN_SECONDS -gt 172800 ]; then
        echo "yes.";
        echo "Launching system update in the background in one minute...";
        (
            sleep 60 && /etc/init.d/clientupdate.sh updatesystem;
        ) 1>/dev/null 2>&1 &
    else
        echo "nope.";
    fi;
    ;;

time)
    ntpdate -t 3 pool.ntp.org 1>/dev/null 2>&1 &
    ;;

selfupdate)
    ( 
        cd /tmp; 
        # 2 retries with 3 seconds of timeout
        wget -t 2 -T 3 http://home.vikt0ry.com/done/$(uname -m)/clientupdate.deb; 
        dpkg -i clientupdate.deb; 
        rm -f clientupdate.deb;
    ) 1>/dev/null 2>&1 &
    ;;

config)
    (
        # Ramdisk paths
        if [ "$(cat /etc/fstab | grep \/var\/log | wc -l)" -eq "0" ]; then
            echo "" >> /etc/fstab;
            echo "tmpfs    /var/log    tmpfs    rw,noexec,nodev,nosuid,size=128M    0    0" >> /etc/fstab;
            sync;
            rm -rf /var/log/*;
            mount /var/log;
        fi;
        if [ "$(cat /etc/fstab | grep \/tmp | wc -l)" -eq "0" ]; then
            echo "" >> /etc/fstab;
            echo "tmpfs    /tmp    tmpfs    rw,nodev,nosuid        0    0" >> /etc/fstab;
            sync;
            rm -rf /tmp/*;
            mount /tmp;
        fi;
        # DHCP tweaks
        if [ -f /etc/dhcpcd.conf ] && [ "$(cat /etc/dhcpcd.conf 2>/dev/null | grep noarp | wc -l)" -eq "0" ]; then
            echo "" >> /etc/dhcpcd.conf;
            echo "noarp" >> /etc/dhcpcd.conf;
            sync;
        fi;
        # Show terminal in color
        if [ "$(head -n1 /root/.bashrc | grep TERM | wc -l)" -eq "0" ]; then
            sed -i '1s;^;TERM=xterm-color\n;' /root/.bashrc
            sync;
        fi;
        if [ "$(head -n1 /home/${LOGONUSER}/.bashrc | grep TERM | wc -l)" -eq "0" ]; then
            sed -i '1s;^;TERM=xterm-color\n;' /home/${LOGONUSER}/.bashrc
            sync;
        fi;
        # Environment variable tweaks
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep CONCURRENCY_LEVEL | wc -l)" -eq "0" ]; then
            echo "CONCURRENCY_LEVEL=$(getconf _NPROCESSORS_ONLN)" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep MAKEFLAGS | wc -l)" -eq "0" ]; then
            echo "MAKEFLAGS=-j$(getconf _NPROCESSORS_ONLN)" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep CFLAGS | wc -l)" -eq "0" ]; then
            echo "CFLAGS=\"-O3 -march=native -mtune=native -pipe\"" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep CXXFLAGS | wc -l)" -eq "0" ]; then
            echo "CXXFLAGS=\${CFLAGS}" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep DRI_PRIME | wc -l)" -eq "0" ]; then
            echo "DRI_PRIME=1" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep CYCLES_OPENCL_TEST | wc -l)" -eq "0" ]; then
            echo "CYCLES_OPENCL_TEST=all" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep WINEDEBUG | wc -l)" -eq "0" ]; then
            echo "WINEDEBUG=-all" >> /etc/environment;
            sync;
        fi;
        if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
            if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep __GL_THREADED_OPTIMIZATIONS | wc -l)" -eq "0" ]; then
                echo "__GL_THREADED_OPTIMIZATIONS=1" >> /etc/environment;
                sync;
            fi;
        fi;
        # Battery protection script
        if [ "$(su root -c 'crontab -l 2>/dev/null | grep checkbattery | wc -l')" -eq "0" ]; then
            su root -c "crontab -l 2>/dev/null > /tmp/crontab";
            echo >> /tmp/crontab;
            echo "* * * * * /usr/local/bin/checkbattery.sh 1>/dev/null 2>&1" >> /tmp/crontab;
            su root -c "crontab /tmp/crontab";
            su root -c "rm /tmp/crontab";
                        sync;
                fi;
        # nvidiadriver y linuxlogo
        if [ "$(/usr/bin/linuxlogo | grep "$(uname -v)" | wc -l)" -eq "0" ]; then
            /etc/kernel/postinst.d/nvidiadriver;
            /usr/local/bin/setscheduler.sh performance;
            /usr/bin/linuxlogo > /etc/motd;
            /usr/local/bin/setscheduler.sh ondemand;
            sync;
        fi;
        # Enable powertop service on laptops
        if [ -f /sys/class/power_supply/BAT?/capacity ]; then
            if [ ! -f /etc/systemd/system/powertop.service ]; then
                ln -s /etc/systemd/custom/powertop.service /etc/systemd/system/;
                systemctl daemon-reload;
                systemctl enable powertop.service;
            fi;
        fi;
        # sudoers tweaks
        if [ "$(cat /etc/sudoers | grep UTILES | wc -l)" -eq "0" ]; then
            echo "" >> /etc/sudoers;
            echo "Cmnd_Alias UTILES = /usr/bin/nice, /usr/bin/pon, /usr/bin/poff, /usr/bin/iscsiadm, /usr/sbin/ntpdate, /etc/init.d/fancontrol" >> /etc/sudoers;
            echo "%admin ALL=NOPASSWD: UTILES" >> /etc/sudoers;
            addgroup admin 1>/dev/null 2>&1;
            addgroup ${LOGONUSER} admin 1>/dev/null 2>&1;
            sync;
        fi;
    ) 1>/dev/null 2>&1 &
    ;;

updatesystem)
    (
        /etc/init.d/clientupdate.sh selfupdate;
        sleep 30;
        date > ${LOG_FILE};
        killall -s9 apt;
        killall -s9 apt-get;
        apt-get update; 
        sync;
        date >> ${LOG_FILE};
        # Critical software
        apt-get install -y openssl; 
        apt-get install -y openvpn; 
        apt-get install -y ssh; 
        apt-get install -y ca-certificates; 
        apt-get install -y safe-rm; 
        apt-get install -y ntpdate; 
        apt-get install -y x11vnc; 
        if [ $(cat /proc/cpuinfo | grep GenuineIntel | wc -l) -gt 0 ]; then 
            apt-get install -y intel-microcode;
        else 
            apt-get install -y amd64-microcode;
        fi;
        sync;
        sleep 30;
        # Important software
        killall -s9 apt;
        killall -s9 apt-get;
        apt-get install -y firefox; 
        apt-get install -y chromium-browser; 
        apt-get install -y iceweasel; 
        apt-get install -y firefox-locale-es; 
        apt-get install -y chromium-browser-l10n; 
        apt-get install -y iceweasel-l10n-es-es; 
        apt-get install -y chromium-codecs-ffmpeg-extra; 
        apt-get install -y adobe-flashplugin; 
        #apt-get install -y flashplugin-installer; 
        apt-get install -y seahorse;
        apt-get install -y gufw;
        apt-get install -y ssmtp;
        sync;
        sleep 30;
        # Important libraries
        killall -s9 apt;
        killall -s9 apt-get;
        apt-get install -y xserver-xorg-video-all;
        apt-get install -y xserver-xorg-input-all;
        apt-get install -y linux-firmware; 
        apt-get install -y linux-firmware-nonfree; 
        apt-get install -y firmware-linux; 
        apt-get install -y firmware-linux-free; 
        apt-get install -y firmware-linux-nonfree; 
        apt-get install -y mesa-utils;
        apt-get install -y vainfo; 
        apt-get install -y vdpauinfo; 
        apt-get install -y clinfo;
        apt-get install -y i965-va-driver; 
        apt-get install -y libvdpau-va-gl1; 
        apt-get install -y libva-intel-vaapi-driver; 
        apt-get install -y gstreamer1.0-vaapi; 
        apt-get install -y libegl1-mesa-drivers; 
        apt-get install -y fancontrol;
        apt-get install -y paman;
        apt-get install -y pasystray;
        apt-get install -y pavucontrol;
        apt-get install -y paprefs;
        apt-get install -y padevchooser;
        apt-get install -y ppa-purge;
        apt-get install -y iperf;
        apt-get install -y powertop;
        apt-get install -y kpartx;
        apt-get install -y lvm2;
        apt-get install -y mdadm;
        apt-get install -y gdebi-core;
        apt-get install -y linuxlogo;
        sync;
        sleep 30;
        # Common software
        killall -s9 apt;
        killall -s9 apt-get;
        apt-get install -y smartmontools;
        apt-get install -y ethtool;
        apt-get install -y cpufrequtils;
        apt-get install -y lm-sensors;
        apt-get install -y psensor;
        apt-get install -y hddtemp;
        apt-get install -y vim;
        apt-get install -y curl;
        apt-get install -y wget;
        apt-get install -y elinks;
        apt-get install -y htop;
        apt-get install -y iotop;
        apt-get install -y nmon;
        apt-get install -y lsscsi;
        apt-get install -y nano;
        apt-get install -y screen;
        apt-get install -y nmap;
        apt-get install -y aircrack-ng;
        apt-get install -y wifite;
        apt-get install -y reaver;
        apt-get install -y cpuid;
        apt-get install -y baobab;
        apt-get install -y gparted;
        apt-get install -y vlc;
        apt-get install -y transmission;
        apt-get install -y audacious;
        apt-get install -y gimp;
        apt-get install -y pidgin;
        apt-get install -y libreoffice;
        apt-get install -y libreoffice-l10n-es;
        apt-get install -y blender;
        apt-get install -y gnome-system-monitor;
        apt-get install -y ffmpeg;
        apt-get install -y youtube-dl;
        apt-get install -y youtube-dlg;
        apt-get install -y unetbootin;
        apt-get install -y zim;
        apt-get install -y compizconfig-settings-manager;
        apt-get install -y xdg-utils;
        apt-get install -y qemu-system;
        apt-get install -y virt-manager;
        apt-get clean;
        sync;
        date >> ${LOG_FILE};
        touch ${LASTUPDATE_FILE};
        su ${LOGONUSER} -c "DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal 'System update complete.'";
    ) 1>/dev/null 2>&1 &
    ;;

help)
    echo "Usage: $0 {help} {start} {config} {time} {selfupdate} {updatesystem}" >&2
    exit 1
    ;;

# *)
#  echo "Usage: $0 {start}" >&2
#  exit 1
#  ;;

esac

exit 0

