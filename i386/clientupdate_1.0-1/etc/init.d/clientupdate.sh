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
UPDATE_URL=https://home.vikt0ry.com/done/$(uname -m)/clientupdate.deb
MAXLASTRUN_SECONDS=$(( 60 * 60 * 24 * 2 ))                                  # 2 days
RETRY_COUNT=2
TIMEOUT_DELAY=5                                                             # seconds
SHORT_DELAY=15                                                              # seconds
NORMAL_DELAY=30                                                             # seconds
LONG_DELAY=60                                                               # seconds
UPDATESYSTEM_ENABLED=1
SELFUPDATE_ENABLED=1
CPUFREQ_SCHEDULER=schedutil
PSTATE_SCHEDULER=performance

if [ -f ${LASTUPDATE_FILE} ]; then
    # Load custom configuration options.
    # You can override the update url, for example.
    . ${LASTUPDATE_FILE}
fi

if [ ! "${INSTALLNVIDIA}" -eq "0" ]; then
    sleep ${SHORT_DELAY} && su ${LOGONUSER} -c "DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal 'Installing latest NVIDIA driver, please wait...'" && sleep ${TIMEOUT_DELAY};
    /usr/src/makenvidia.sh &
    exit 0;
fi

if [ ! -f ${LASTUPDATE_FILE} ]; then
    touch ${LASTUPDATE_FILE};
    echo "First run, launching system update in the background in one minute...";
    (
        sleep ${LONG_DELAY} && /etc/init.d/clientupdate.sh updatesystem;
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
    if [ ! "${SELFUPDATE_ENABLED}" -eq "1" ]; then
        echo "Self update is disabled in ${LASTUPDATE_FILE}.";
    else
        echo -n "Launching selfupdate in the background... ";
        /etc/init.d/clientupdate.sh selfupdate;
        echo "done.";
    fi;
    echo -n "Verifying system configuration in the background... ";
    /etc/init.d/clientupdate.sh config;
    echo "done.";
    if [ ! "${UPDATESYSTEM_ENABLED}" -eq "1" ]; then
        echo "System update is disabled in ${LASTUPDATE_FILE}.";
    else
        echo -n "Checking if system update is needed... ";
        if [ $LASTRUN_SECONDS -gt ${MAXLASTRUN_SECONDS} ]; then
            echo "yes.";
            echo "Launching system update in the background in one minute...";
            (
                sleep ${LONG_DELAY} && /etc/init.d/clientupdate.sh updatesystem;
            ) 1>/dev/null 2>&1 &
        else
            echo "nope.";
        fi;
    fi;
    ;;

time)
    ntpdate -t ${TIMEOUT_DELAY} pool.ntp.org 1>/dev/null 2>&1 &
    ;;

selfupdate)    
    ( 
        cd /tmp; 
        # ${RETRY_COUNT} retries with ${TIMEOUT_DELAY} seconds of timeout
        wget --https-only -t ${RETRY_COUNT} -T ${TIMEOUT_DELAY} "${UPDATE_URL}"; 
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
        # Group tweaks
        if [ "$(cat /etc/group | grep steam | wc -l)" -eq "0" ]; then
            # Group used for steam controller access
            addgroup steam;
            addgroup ${LOGONUSER} steam;
            addgroup ${LOGONUSER} input;
            sync;
        fi;
        # Allow connection to ipsec servers that use certificates created by public CAs
        if [ ! -d /etc/ipsec.d ]; then
            mkdir /etc/ipsec.d;
        fi;
        if [ ! -L /etc/ipsec.d/cacerts ]; then
            if [ -d /etc/ipsec.d/cacerts ]; then
                rmdir /etc/ipsec.d/cacerts;
            fi;
            ln -s /etc/ssl/certs /etc/ipsec.d/cacerts;
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
            echo "CXXFLAGS=\"-O3 -march=native -mtune=native -pipe\"" >> /etc/environment;
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
        if [ ! -f /usr/lib/x86_64-linux-gnu/dri/vdpau_drv_video.so ]; then
            cp -xaRP /usr/src/vdpau-va-driver/* /usr/lib/x86_64-linux-gnu/dri/
            chown root.root /usr/lib/x86_64-linux-gnu/dri/*
        fi;
        if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep GOOGLE_API_KEY | wc -l)" -eq "0" ]; then
            echo "#GOOGLE_API_KEY=your_api_key" >> /etc/environment;
            echo "#GOOGLE_DEFAULT_CLIENT_ID=your_client_id" >> /etc/environment;
            echo "#GOOGLE_DEFAULT_CLIENT_SECRET=your_client_secret" >> /etc/environment;
            sync;
        fi;
        if [ -f /etc/default/apport ] && [ "$(cat /etc/default/apport 2>/dev/null | grep "enabled=0" | wc -l)" -eq "0" ]; then
            echo "enabled=0" > /etc/default/apport;
            sync;
        fi;
        if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
            if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep __GL_THREADED_OPTIMIZATIONS | wc -l)" -eq "0" ]; then
                echo "__GL_THREADED_OPTIMIZATIONS=1" >> /etc/environment;
                sync;
            fi;
            if [ -f /etc/environment ] && [ "$(cat /etc/environment 2>/dev/null | grep __GL_SYNC_DISPLAY_DEVICE | wc -l)" -eq "0" ]; then
                echo "__GL_SYNC_DISPLAY_DEVICE="$(LANG=C DISPLAY=:0.0 xrandr | grep primary | cut -d\  -f1) >> /etc/environment;
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
        # nvidiadriver and linuxlogo
        if [ "$(cat /etc/motd | grep "$(uname -v)" | wc -l)" -eq "0" ]; then
            /etc/kernel/postinst.d/nvidiadriver;
            /usr/local/bin/setscheduler.sh performance;
            /usr/bin/linuxlogo > /etc/motd 2>/dev/null;
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
        # Enable rc.local service when missing
        if [ ! -f /etc/rc.local ]; then
            cp /etc/rclocal.default /etc/rc.local
            chown root.root /etc/rc.local
            chmod 755 /etc/rc.local
        fi;
        if [ "$( systemctl is-enabled rc-local 1>/dev/null 2>&1 && echo 1 || echo 0 )" -eq "0" ]; then
            if [ ! -f /etc/systemd/system/rc-local.service ]; then
                ln -s /etc/systemd/custom/rc-local.service /etc/systemd/system/;
                systemctl daemon-reload;
                systemctl enable rc-local;
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
        # nice permissions
        if [ -f /etc/security/limits.conf ] && [ "$(cat /etc/security/limits.conf 2>/dev/null | grep ${LOGONUSER} | wc -l)" -eq "0" ]; then
            echo "${LOGONUSER} - nice -10" >> /etc/security/limits.conf;
            sync;
        fi;
        # Intel GM965 bug bypass
        if [ "$(lspci | grep VGA | grep Intel | grep Mobile | grep GM9 | wc -l)" -eq "1" ] && [ "$(cat /etc/default/grub | grep SVIDEO-1 | wc -l)" -eq "0" ]; then
            sed -i 's#^\(GRUB_CMDLINE_LINUX_DEFAULT="\)#\1video=SVIDEO-1:d #' /etc/default/grub;
            update-grub 1>/dev/null 2>&1;
            sync;
        fi;
        # IO Scheduler settings
        if [ "$(cat /etc/default/grub | grep use_blk_mq | wc -l)" -eq "0" ]; then
            sed -i 's#^\(GRUB_CMDLINE_LINUX_DEFAULT="\)#\1ipv6.disable_ipv6=1 scsi_mod.use_blk_mq=y dm_mod.use_blk_mq=y #' /etc/default/grub;
            update-grub 1>/dev/null 2>&1;
            sync;
        fi;
        # munin settings
        if [ -f /etc/munin/munin-node.conf ] && [ ! "$(diff /etc/munin/munin-node.cu.conf /etc/munin/munin-node.conf | wc -l)" -eq "0" ]; then
            cat /etc/munin/munin-node.cu.conf > /etc/munin/munin-node.conf;
            /etc/init.d/munin-node restart;
            sync;
        fi;
        # systemd-resolved settings
        if [ -f /etc/systemd/resolved.conf ] && [ "$(cat /etc/systemd/resolved.conf | grep 8\.8\.8\.8 | wc -l)" -eq "0" ]; then
            echo "DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
            echo "Cache=yes" >> /etc/systemd/resolved.conf
            systemctl restart systemd-resolved;
            if [ -f /run/systemd/resolve/resolv.conf ]; then
                rm -f /etc/resolv.conf;
                ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf;
            fi;
            sync;
        fi;
        ## systemd-networkd disable
        #if [ "$( systemctl is-enabled systemd-networkd 2>&1 | grep enabled | head -n 1 | wc -l || echo 0 )" -eq "1" ]; then
        #    apt-get -y install ifupdown 1>/dev/null 2>&1;
        #    apt-get -y purge netplan.io 1>/dev/null 2>&1;
        #    systemctl stop systemd-networkd systemd-networkd-wait-online;
        #    systemctl disable systemd-networkd systemd-networkd-wait-online;
        #    sync;
        #fi;
        # CPU governor settings
        if [ "$(cpufreq-info | grep driver | grep intel_pstate | wc -l)" -eq "0" ]; then
            # If we are using cpufreq driver, use schedutil governor.
            /usr/local/bin/setscheduler.sh ${CPUFREQ_SCHEDULER} 1>/dev/null 2>&1;
        else
            # If we are using intel-pstate driver, use performance governor.
            /usr/local/bin/setscheduler.sh ${PSTATE_SCHEDULER} 1>/dev/null 2>&1;
        fi;
    ) 1>/dev/null 2>&1 &
    ;;

updatesystem)
    (
        /etc/init.d/clientupdate.sh selfupdate;
        sleep ${NORMAL_DELAY};
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
        apt-get install -y rng-tools;
        apt-get install -y haveged;
        if [ $(cat /proc/cpuinfo | grep GenuineIntel | wc -l) -gt 0 ]; then 
            apt-get install -y intel-microcode;
        else 
            apt-get install -y amd64-microcode;
        fi;
        sync;
        sleep ${NORMAL_DELAY};
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
        apt-get install -y ifupdown;
        apt-get install -y gufw;
        apt-get install -y fprintd;
        apt-get install -y libpam-fprintd;
        apt-get install -y opensc-pkcs11;
        apt-get install -y wakeonlan;
        apt-get install -y msmtp;
        apt-get install -y p7zip-full;
        apt-get install -y p7zip-rar;
        apt-get install -y pigz;
        sync;
        sleep ${NORMAL_DELAY};
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
        apt-get install -y vdpau-va-driver;
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
        apt-get install -y screenfetch;
        sync;
        sleep ${NORMAL_DELAY};
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
        apt-get install -y whois;
        apt-get install -y dnsutils;
        apt-get install -y net-tools;
        apt-get install -y elinks;
        apt-get install -y pv;
        apt-get install -y htop;
        apt-get install -y iotop;
        apt-get install -y nmon;
        apt-get install -y lsscsi;
        apt-get install -y nano;
        apt-get install -y screen;
        apt-get install -y nmap;
        apt-get install -y aircrack-ng;
        apt-get install -y reaver;
        apt-get install -y cpuid;
        apt-get install -y baobab;
        apt-get install -y gparted;
        apt-get install -y vlc;
        apt-get install -y transmission;
        apt-get install -y simplescreenrecorder;
        apt-get install -y audacious;
        apt-get install -y gimp;
        apt-get install -y pidgin;
        apt-get install -y libreoffice;
        apt-get install -y libreoffice-l10n-es;
        apt-get install -y calibre;
        apt-get install -y blender;
        apt-get install -y gnome-system-monitor;
        apt-get install -y mate-system-monitor;
        apt-get install -y gnome-clocks;
        apt-get install -y ffmpeg;
        apt-get install -y youtube-dl;
        apt-get install -y youtube-dlg;
        apt-get install -y unetbootin;
        apt-get install -y zim;
        apt-get install -y compizconfig-settings-manager;
        apt-get install -y xdg-utils;
        apt-get install -y qemu-system;
        apt-get install -y virt-manager;
        apt-get install -y mediainfo;
        apt-get install -y nethogs;
        apt-get install -y tree;
        apt-get install -y eog;
        apt-get install -y munin-node;
        apt-get install -y binwalk;
        apt-get install -y strongswan-nm;
        apt-get install -y strongswan;
        apt-get install -y libcharon-standard-plugins;
        apt-get install -y libcharon-extra-plugins;
        apt-get install -y network-manager-strongswan;
        apt-get install -y guake;
        apt-get install -y i7z;
        apt-get install -y meld;
        apt-get install -y stockfish;
        apt-get install -y jerry;
        apt-get install -y cloud-guest-utils;
        apt-get install -y xnest;
        apt-get install -y mkvtoolnix;
        apt-get install -y mkvtoolnix-gui;
        apt-get install -y exfat-fuse;
        apt-get install -y exfat-utils;
        apt-get install -y ntfs-3g;
        apt-get install -y ntfs-config;
        apt-get install -y bpfcc-tools;
        sync;
        # The following applications show some messages on first install, so they are kept at the end
        apt-get install -y mailutils;
        apt-get install -y wifite;
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

