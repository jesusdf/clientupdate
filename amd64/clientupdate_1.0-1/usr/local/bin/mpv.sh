#!/bin/bash

CONFIG_FILE=/etc/default/clientupdate
NVIDIA_GPU=$(lspci | grep NVIDIA | wc -l)
CRYSTALHD=$(lspci | grep BCM | grep Crystal\ HD | wc -l)
MPV_HWDEC=$(/usr/local/bin/mpv -hwdec=help | grep -v copy)
NVDEC=$(echo ${MPV_HWDEC} | grep nvdec | wc -l)
VAAPI=$(echo ${MPV_HWDEC} | grep vaapi | wc -l)
VDPAU=$(echo ${MPV_HWDEC} | grep vdpau | wc -l)
ATOM=$(cat /proc/cpuinfo | grep Atom | head -n 1 | wc -l)
RATIOTV=$(DISPLAY=:0.0 xrandr | grep \* | head -n 1 | xargs | cut -d\  -f1 | sed 's/x/ x /g' | awk '{print $1/$3}')
RATIOVIDEO=$(mediainfo "$1" | grep aspect\ ratio | xargs | cut -d\  -f5- | sed 's/:/ x /g' | awk '{print $1/$3}')
MPV_LOCAL_OPTIONS=

echo -n "> Screen ratio: $RATIOTV, Video ratio: $RATIOVIDEO, "
if [ "$RATIOTV" == "$RATIOVIDEO" ]; then
    echo "leaving as is."
    RATIOPARAM=
else
    echo "using panscan to fill the screen."
    RATIOPARAM=--panscan=1.0
fi

if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
    if [ ! "${VDPAU}" -eq "0" ]; then
        HWDEC=vdpau
    else
        if [ ! "${NVDEC}" -eq "0" ]; then
            # NVDEC is slow with 10bit sources
            HWDEC=nvdec
        else
            HWDEC=vaapi
        fi
    fi
else
    if [ ! "${CRYSTALHD}" -eq "0" ]; then
        HWDEC=crystalhd
    else
        if [ ! "${VAAPI}" -eq "0" ]; then
            HWDEC=vaapi
        else
            if [ ! "${VDPAU}" -eq "0" ]; then
                HWDEC=vdpau
            else
                HWDEC=auto
            fi
        fi
    fi
fi

if [ ! "${ATOM}" -eq "0" ]; then
    # Usually old Atom computers only support OPENGL 1.4
    export MESA_GL_VERSION_OVERRIDE=2.1
fi

if [ -f ${CONFIG_FILE} ]; then
    # Load custom configuration options.
    . ${CONFIG_FILE}
fi

echo "> Using $HWDEC hardware decoder."

if [ "$1"!="" ]; then
    /usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=${HWDEC} -vo=gpu,xv -ao=pulse --audio-channels=6 $RATIOPARAM $MPV_LOCAL_OPTIONS -fs "$1"
fi

IS_DEFAULT=$(/usr/bin/xdg-mime query default video/x-matroska)

if [ "${IS_DEFAULT}"!="mpv-custom.desktop" ]; then
    # Set as default application
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-matroska
    /usr/bin/xdg-mime default mpv-custom.desktop application/x-matroska
    /usr/bin/xdg-mime default mpv-custom.desktop video/mp4
    /usr/bin/xdg-mime default mpv-custom.desktop application/x-extension-mp4
    /usr/bin/xdg-mime default mpv-custom.desktop video/mp4v-es
    /usr/bin/xdg-mime default mpv-custom.desktop video/mpeg
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-mpeg
    /usr/bin/xdg-mime default mpv-custom.desktop video/msvideo
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-msvideo
    /usr/bin/xdg-mime default mpv-custom.desktop video/quicktime
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-ms-wmv
    /usr/bin/xdg-mime default mpv-custom.desktop video/webm
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-avi
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-flv
fi

